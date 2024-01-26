terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    archive = {
      source = "hashicorp/archive"
    }
    null = {
      source = "hashicorp/null"
    }
  }

  required_version = ">= 1.3.7"

  backend "s3" {
    bucket                  = "terraform-buckets-food-totem"
    key                     = "jwt-lambda/terraform.tfstate"
    region                  = "us-west-2"
  }
}

locals {
  src_path     = "main.go"
  binary_name  = "bootstrap"
  binary_path  = "./${local.binary_name}"
  archive_path = "./${local.binary_name}.zip"
}

provider "aws" {
  region = "us-west-2"
}

# resource "null_resource" "function_binary" {
#   provisioner "local-exec" {
#     command = "GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GOFLAGS=-trimpath go build -mod=readonly -ldflags='-s -w' -o ${local.binary_path} ${local.src_path}"
#   }
# }

data "aws_security_group" "default" {
  name = "default"
}

data "aws_vpc" "default" {
  default = true
}

data "archive_file" "function_archive" {
  # depends_on = [null_resource.function_binary]

  type        = "zip"
  source_file = local.binary_path
  output_path = local.archive_path
}

resource "aws_lambda_function" "food-totem-jwt" {
  function_name = "food-totem-jwt"
  description   = "JWT Generator for food totem"
  role          = "arn:aws:iam::${var.lab_account_id}:role/LabRole"
  handler       = local.binary_name
  memory_size   = 128

  filename         = local.archive_path
  source_code_hash = data.archive_file.function_archive.output_base64sha256

  runtime = "go1.x"

  environment {
    variables = {
      JWT_SECRET_KEY = var.jwt_secret_key
    }
  }
}