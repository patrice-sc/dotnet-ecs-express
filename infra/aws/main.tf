provider "aws" {
  region = var.aws_region
}

module "app" {
  source = "../../resources/terraform/ecs-express"

  name                    = var.name
  vpc_id                  = var.vpc_id
  private_subnet_ids      = var.private_subnet_ids
  database_engine_version = var.database_engine_version
  deploy_service          = var.deploy_service
  container_image_tag     = var.container_image_tag
  tags = {
    Application = var.name
    ManagedBy   = "Terraform"
  }
}
