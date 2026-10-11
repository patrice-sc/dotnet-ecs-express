terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.68.0, < 7.0.0"
    }
  }

  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the ECR repository."
  type        = string
  default     = "eu-west-3"
}

variable "repository_name" {
  description = "Unique ECR repository name, separate from the full ECS deployment."
  type        = string
  default     = "dotnet-ecs-express-starter"

  validation {
    condition     = length(var.repository_name) >= 2 && length(var.repository_name) <= 256 && can(regex("^[a-z][a-z0-9]*([._/-][a-z0-9]+)*$", var.repository_name))
    error_message = "Use an ECR name of 2-256 characters, starting with a lowercase letter and containing lowercase letters, digits, and separators (. _ / -)."
  }
}

resource "aws_ecr_repository" "starter" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }
}

output "repository_url" {
  description = "URL of the empty ECR repository."
  value       = aws_ecr_repository.starter.repository_url
}
