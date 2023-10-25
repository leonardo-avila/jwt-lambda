terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    archive = {
      source = "hashicorp/archive"
    }
    null = {
      source = "hashicorp/null"
    }
  }

  required_version = ">= 1.3.7"
}

locals {
  src_path = "main.go"
  binary_name = "bootstrap"
  binary_path = "./${local.binary_name}"
  archive_path = "./${local.binary_name}.zip"
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

provider "aws" {
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  default_tags {
    tags = {
      app = "lambda-jwt"
    }
  }
}

data "aws_iam_policy_document" "assume_lambda_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "AssumeLambdaRole"
  description        = "Role for lambda to assume lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda_role.json
}

# resource "null_resource" "function_binary" {
#   provisioner "local-exec" {
#     command = "GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GOFLAGS=-trimpath go build -mod=readonly -ldflags='-s -w' -o ${local.binary_path} ${local.src_path}"
#   }
# }

data "archive_file" "function_archive" {
  # depends_on = [null_resource.function_binary]

  type        = "zip"
  source_file = local.binary_path
  output_path = local.archive_path
}

resource "aws_lambda_function" "jwt-generator" {
  function_name = "jwt-generator"
  description   = "JWT Generator for food totem"
  role          = aws_iam_role.lambda.arn
  handler       = local.binary_name
  memory_size   = 128

  filename         = local.archive_path
  source_code_hash = data.archive_file.function_archive.output_base64sha256

  runtime = "go1.x"
}

resource "aws_api_gateway_rest_api" "jwt-api" {
  name        = "API Gateway for JWT Generator Lambda"
  description = "Provides a gateway to call the JWT Generator Lambda"
}

resource "aws_api_gateway_resource" "jwt-proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.jwt-api.id}"
  parent_id   = "${aws_api_gateway_rest_api.jwt-api.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "jwt-proxy" {
  rest_api_id   = "${aws_api_gateway_rest_api.jwt-api.id}"
  resource_id   = "${aws_api_gateway_resource.jwt-proxy.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "jwt-lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.jwt-api.id}"
  resource_id = "${aws_api_gateway_method.jwt-proxy.resource_id}"
  http_method = "${aws_api_gateway_method.jwt-proxy.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.jwt-generator.invoke_arn}"
}

resource "aws_api_gateway_method" "jwt_proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.jwt-api.id}"
  resource_id   = "${aws_api_gateway_rest_api.jwt-api.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "jwt_lambda_root" {
  rest_api_id = "${aws_api_gateway_rest_api.jwt-api.id}"
  resource_id = "${aws_api_gateway_method.jwt_proxy_root.resource_id}"
  http_method = "${aws_api_gateway_method.jwt_proxy_root.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.jwt-generator.invoke_arn}"
}

resource "aws_api_gateway_deployment" "jwt-api-deployment" {
  depends_on = [
    aws_api_gateway_integration.jwt-lambda,
    aws_api_gateway_integration.jwt_lambda_root,
  ]

  rest_api_id = "${aws_api_gateway_rest_api.jwt-api.id}"
  stage_name  = "prod"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.jwt-generator.function_name}"
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.jwt-api.execution_arn}/*/*"
}