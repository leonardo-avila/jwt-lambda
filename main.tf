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

# variable "aws_access_key" {
#   type = string
# }

# variable "aws_secret_key" {
#   type = string
# }

provider "aws" {
  region = "us-east-1"
  # access_key = var.aws_access_key
  # secret_key = var.aws_secret_key

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

resource "null_resource" "function_binary" {
  provisioner "local-exec" {
    command = "GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GOFLAGS=-trimpath go build -mod=readonly -ldflags='-s -w' -o ${local.binary_path} ${local.src_path}"
  }
}

data "archive_file" "function_archive" {
  depends_on = [null_resource.function_binary]

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

# resource "aws_api_gateway_rest_api" "jwt_api" {
#   name        = "jwt_api"
#   description = "API Gateway for JWT Generator Lambda"
# }

# resource "aws_api_gateway_resource" "jwt_resource" {
#   rest_api_id = aws_api_gateway_rest_api.jwt_api.id
#   parent_id   = aws_api_gateway_rest_api.jwt_api.root_resource_id
#   path_part   = "jwt"
# }

# resource "aws_api_gateway_method" "jwt_method" {
#   rest_api_id   = aws_api_gateway_rest_api.jwt_api.id
#   resource_id   = aws_api_gateway_resource.jwt_resource.id
#   http_method   = "POST"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "jwt_integration" {
#   rest_api_id = aws_api_gateway_rest_api.jwt_api.id
#   resource_id = aws_api_gateway_resource.jwt_resource.id
#   http_method = aws_api_gateway_method.jwt_method.http_method

#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.jwtGenerator.invoke_arn
# }

# resource "aws_lambda_permission" "jwt_permission" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.jwtGenerator.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = aws_api_gateway_rest_api.jwt_api.execution_arn
# }

# resource "aws_iam_role_policy_attachment" "api-gateway" {
#   policy_arn = "arn:aws:iam::${var.aws_account_number}:policy/AllowLambdaJwtGeneratorInvoke"
#   role       = aws_iam_role.lambda-jwt.name
# }