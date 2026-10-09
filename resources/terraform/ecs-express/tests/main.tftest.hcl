mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_ecr_image" {
    defaults = {
      image_digest = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  }

  mock_resource "aws_rds_cluster" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:rds-admin-test"
        secret_status = "active"
        kms_key_id    = "arn:aws:kms:eu-west-1:123456789012:key/test"
      }]
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test-role"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:eu-west-1:123456789012:cluster/test-app"
    }
  }

  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/test-app"
    }
  }
}

override_data {
  target = data.aws_subnet.selected["subnet-a"]
  values = {
    vpc_id                  = "vpc-test"
    availability_zone       = "eu-west-1a"
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = false
  }
}

override_data {
  target = data.aws_subnet.selected["subnet-b"]
  values = {
    vpc_id                  = "vpc-test"
    availability_zone       = "eu-west-1b"
    cidr_block              = "10.0.2.0/24"
    map_public_ip_on_launch = false
  }
}

variables {
  name                    = "test-app"
  vpc_id                  = "vpc-test"
  private_subnet_ids      = ["subnet-a", "subnet-b"]
  database_engine_version = "16.6"
}

run "bootstrap" {
  command = apply

  assert {
    condition     = length(aws_ecs_express_gateway_service.app) == 0 && length(data.aws_ecr_image.app) == 0
    error_message = "Bootstrap must not require or deploy an image."
  }

  assert {
    condition     = aws_ecr_repository.app.image_tag_mutability == "IMMUTABLE" && !aws_ecr_repository.app.force_delete
    error_message = "ECR must protect image tags and reject deletion of a non-empty repository."
  }

  assert {
    condition     = aws_rds_cluster.database.engine == "aurora-postgresql" && aws_rds_cluster.database.manage_master_user_password && aws_rds_cluster.database.storage_encrypted
    error_message = "Aurora must use PostgreSQL, encryption, and an RDS-managed password."
  }

  assert {
    condition     = aws_rds_cluster.database.deletion_protection && !aws_rds_cluster.database.skip_final_snapshot && length(aws_rds_cluster_instance.database) == 2
    error_message = "Protect the database and provision writer/failover capacity."
  }

  assert {
    condition     = alltrue([for instance in aws_rds_cluster_instance.database : instance.instance_class == "db.serverless" && !instance.publicly_accessible]) && length(distinct([for instance in aws_rds_cluster_instance.database : instance.availability_zone])) == 2
    error_message = "Database instances must be private Serverless v2 instances across two AZs."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.database.referenced_security_group_id == aws_security_group.app.id && aws_vpc_security_group_ingress_rule.database.from_port == 5432
    error_message = "Only the application security group may reach PostgreSQL."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.infrastructure.policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
    error_message = "Use the correct Express Mode managed policy ARN."
  }
}

run "deploy_container" {
  command = apply

  variables {
    deploy_service      = true
    container_image_tag = "42"
  }

  assert {
    condition     = length(aws_ecs_express_gateway_service.app) == 1 && aws_ecs_express_gateway_service.app[0].wait_for_steady_state
    error_message = "Deployment must create an Express service and wait for healthy tasks."
  }

  assert {
    condition     = aws_ecs_express_gateway_service.app[0].primary_container[0].image == "${aws_ecr_repository.app.repository_url}@${data.aws_ecr_image.app[0].image_digest}"
    error_message = "Deploy the selected ECR image by immutable digest."
  }

  assert {
    condition     = aws_ecs_express_gateway_service.app[0].health_check_path == "/health" && aws_ecs_express_gateway_service.app[0].primary_container[0].container_port == 8080
    error_message = "Use the sample API health endpoint and .NET SDK container port."
  }

  assert {
    condition     = length(aws_ecs_express_gateway_service.app[0].primary_container[0].secret) == 0
    error_message = "Do not expose the database admin credentials to the application."
  }
}

run "reject_wrong_vpc" {
  command = plan

  variables {
    vpc_id = "vpc-other"
  }

  expect_failures = [aws_db_subnet_group.database]
}

run "reject_single_az" {
  command = plan

  override_data {
    target = data.aws_subnet.selected["subnet-b"]
    values = {
      vpc_id                  = "vpc-test"
      availability_zone       = "eu-west-1a"
      cidr_block              = "10.0.2.0/24"
      map_public_ip_on_launch = false
    }
  }

  expect_failures = [aws_db_subnet_group.database]
}

run "reject_public_ip_assignment" {
  command = plan

  override_data {
    target = data.aws_subnet.selected["subnet-b"]
    values = {
      vpc_id                  = "vpc-test"
      availability_zone       = "eu-west-1b"
      cidr_block              = "10.0.2.0/24"
      map_public_ip_on_launch = true
    }
  }

  expect_failures = [aws_db_subnet_group.database]
}
