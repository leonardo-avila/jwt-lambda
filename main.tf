terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
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
}

resource "aws_lambda_function" "jwtGenerator" {
  filename      = "jwtGenerator.zip"
  function_name = "jwtGenerator"
  role          = aws_iam_role.lambda-jwt.arn
  handler       = "jwtGenerator"
  runtime       = "provided.al2"
  source_code_hash = filebase64sha256("jwtGenerator.zip")
}

resource "aws_iam_role" "lambda-jwt" {
  name = "lambda-jwt"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-jwt" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda-jwt.name
}