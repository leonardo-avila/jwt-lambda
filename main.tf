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

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
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

resource "aws_ecs_task_definition" "rabbitmq_task" {
  family                   = "food-totem-rabbitmq"
  execution_role_arn       = "arn:aws:iam::${var.lab_account_id}:role/LabRole"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  container_definitions = jsonencode(
  [
    {
      "name": "food-totem-rabbitmq",
      "image": "rabbitmq:management",
      "portMappings": [
        {
          "containerPort": 5672,
          "hostPort": 5672,
          "protocol": "tcp"
        },
        {
          "containerPort": 15672,
          "hostPort": 15672,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "RABBITMQ_DEFAULT_USER",
          "value": var.rabbitMQ_user
        },
        {
          "name": "RABBITMQ_DEFAULT_PASS",
          "value": var.rabbitMQ_password
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "food-totem-rabbitmq-logs",
            "awslogs-region": "us-west-2",
            "awslogs-stream-prefix": "food-totem-rabbitmq"
        }
      },
      "cpu": 256,
      "memory": 512
    }
  ])
}

resource "aws_ecs_service" "rabbitmq_service" {
  name            = "rabbitmq-service"
  cluster         = "food-totem-ecs"
  task_definition = aws_ecs_task_definition.rabbitmq_task.arn
  desired_count   = 1
  launch_type = "FARGATE"

  network_configuration {
    security_groups  = [data.aws_security_group.default.id]
    subnets = data.aws_subnets.default.ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.rabbitmq_target_group.arn
    container_name   = "food-totem-rabbitmq"
    container_port   = 5672
  }

  health_check_grace_period_seconds = 120

  load_balancer {
    target_group_arn = aws_lb_target_group.rabbitmq_management_target_group.arn
    container_name   = "food-totem-rabbitmq"
    container_port   = 15672
  }
}

resource "aws_lb" "rabbitmq_lb" {
  name               = "rabbitmq-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "rabbitmq_target_group" {
  name     = "rabbitmq-target-group"
  port     = 5672
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "rabbitmq_listener" {
  load_balancer_arn = aws_lb.rabbitmq_lb.arn
  port              = 5672
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.rabbitmq_target_group.arn
    type             = "forward"
  }
}

resource "aws_lb" "rabbitmq_management_lb" {
  name               = "rabbitmq-management-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "rabbitmq_management_target_group" {
  name     = "rabbitmq-management-target-group"
  port     = 15672
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_listener" "rabbitmq_management_listener" {
  load_balancer_arn = aws_lb.rabbitmq_management_lb.arn
  port              = 15672
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.rabbitmq_management_target_group.arn
    type             = "forward"
  }
}

resource "aws_cloudwatch_log_group" "food-totem-rabbitmq-logs" {
  name = "food-totem-rabbitmq-logs"
  retention_in_days = 1
}