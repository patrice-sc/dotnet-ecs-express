data "aws_partition" "current" {}

data "aws_subnet" "selected" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

locals {
  availability_zones = sort(distinct([for subnet in data.aws_subnet.selected : subnet.availability_zone]))
}

resource "aws_ecr_repository" "app" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

data "aws_ecr_image" "app" {
  count           = var.deploy_service ? 1 : 0
  repository_name = aws_ecr_repository.app.name
  image_tag       = var.container_image_tag
}

resource "aws_ecs_cluster" "app" {
  name = var.name
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name}"
  retention_in_days = 30
  tags              = var.tags
}

data "aws_iam_policy_document" "execution_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "infrastructure_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.execution_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.execution_trust.json
  tags               = var.tags
}

resource "aws_iam_role" "infrastructure" {
  name               = "${var.name}-infrastructure"
  assume_role_policy = data.aws_iam_policy_document.infrastructure_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "infrastructure" {
  role       = aws_iam_role.infrastructure.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
}

resource "aws_security_group" "app" {
  name_prefix = "${var.name}-app-"
  description = "Express Mode application tasks"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each          = data.aws_subnet.selected
  security_group_id = aws_security_group.app.id
  description       = "HTTP from the Express load balancer subnets"
  cidr_ipv4         = each.value.cidr_block
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound access to AWS APIs, image layers, and the database"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "database" {
  name_prefix = "${var.name}-database-"
  description = "Aurora PostgreSQL access from application tasks only"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.app.id
  description                  = "PostgreSQL from application tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_subnet_group" "database" {
  name       = var.name
  subnet_ids = var.private_subnet_ids
  tags       = var.tags

  lifecycle {
    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.selected : subnet.vpc_id == var.vpc_id])
      error_message = "All selected subnets must belong to the supplied VPC."
    }
    precondition {
      condition     = length(local.availability_zones) >= 2
      error_message = "Selected subnets must span at least two Availability Zones."
    }
    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.selected : !subnet.map_public_ip_on_launch])
      error_message = "Use private subnets with automatic public IP assignment disabled."
    }
  }
}

resource "aws_rds_cluster" "database" {
  cluster_identifier          = var.name
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  engine_version              = var.database_engine_version
  database_name               = var.database_name
  master_username             = "clusteradmin"
  manage_master_user_password = true
  storage_encrypted           = true
  db_subnet_group_name        = aws_db_subnet_group.database.name
  vpc_security_group_ids      = [aws_security_group.database.id]
  port                        = 5432
  backup_retention_period     = 7
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "${var.name}-final"
  copy_tags_to_snapshot       = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }

  tags = var.tags
}

resource "aws_rds_cluster_instance" "database" {
  count                = var.database_instance_count
  identifier           = "${var.name}-${count.index + 1}"
  cluster_identifier   = aws_rds_cluster.database.id
  engine               = aws_rds_cluster.database.engine
  engine_version       = aws_rds_cluster.database.engine_version
  instance_class       = "db.serverless"
  db_subnet_group_name = aws_db_subnet_group.database.name
  availability_zone    = local.availability_zones[count.index % length(local.availability_zones)]
  publicly_accessible  = false
  promotion_tier       = count.index
  tags                 = var.tags
}

resource "aws_ecs_express_gateway_service" "app" {
  count                   = var.deploy_service ? 1 : 0
  service_name            = var.name
  cluster                 = aws_ecs_cluster.app.arn
  execution_role_arn      = aws_iam_role.execution.arn
  task_role_arn           = aws_iam_role.task.arn
  infrastructure_role_arn = aws_iam_role.infrastructure.arn
  cpu                     = "256"
  memory                  = "512"
  health_check_path       = "/health"
  wait_for_steady_state   = true

  primary_container {
    image          = "${aws_ecr_repository.app.repository_url}@${data.aws_ecr_image.app[0].image_digest}"
    container_port = 8080

    aws_logs_configuration {
      log_group         = aws_cloudwatch_log_group.app.name
      log_stream_prefix = "api"
    }

    environment {
      name  = "ASPNETCORE_HTTP_PORTS"
      value = "8080"
    }
    environment {
      name  = "PGHOST"
      value = aws_rds_cluster.database.endpoint
    }
    environment {
      name  = "PGPORT"
      value = tostring(aws_rds_cluster.database.port)
    }
    environment {
      name  = "PGDATABASE"
      value = var.database_name
    }
    environment {
      name  = "PGSSLMODE"
      value = "verify-full"
    }
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.app.id]
  }

  scaling_target {
    min_task_count            = 1
    max_task_count            = 2
    auto_scaling_metric       = "AVERAGE_CPU"
    auto_scaling_target_value = 60
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy_attachment.infrastructure,
    aws_vpc_security_group_ingress_rule.app,
    aws_vpc_security_group_egress_rule.app,
    aws_vpc_security_group_ingress_rule.database,
    aws_rds_cluster_instance.database,
  ]
}
