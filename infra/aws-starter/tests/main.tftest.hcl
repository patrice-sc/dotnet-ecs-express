mock_provider "aws" {
  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.eu-west-3.amazonaws.com/dotnet-ecs-express-starter"
    }
  }
}

run "empty_repository" {
  command = apply

  assert {
    condition     = aws_ecr_repository.starter.name == "dotnet-ecs-express-starter"
    error_message = "The starter must use its own repository name."
  }

  assert {
    condition     = aws_ecr_repository.starter.image_tag_mutability == "IMMUTABLE" && !aws_ecr_repository.starter.force_delete
    error_message = "Protect image tags and reject deletion of a non-empty repository."
  }

  assert {
    condition     = one(aws_ecr_repository.starter.encryption_configuration).encryption_type == "AES256"
    error_message = "Encrypt the repository without requiring a separate KMS key."
  }

  assert {
    condition     = output.repository_url == "123456789012.dkr.ecr.eu-west-3.amazonaws.com/dotnet-ecs-express-starter"
    error_message = "Expose the repository URL."
  }
}

run "custom_repository" {
  command = plan

  variables {
    repository_name = "custom-starter"
  }

  assert {
    condition     = aws_ecr_repository.starter.name == "custom-starter"
    error_message = "Respect the supplied repository name."
  }
}

run "invalid_repository" {
  command = plan

  variables {
    repository_name = "Invalid Name"
  }

  expect_failures = [var.repository_name]
}
