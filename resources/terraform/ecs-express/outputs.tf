output "ecr_repository_url" {
  description = "Destination repository for the SDK-built container image."
  value       = aws_ecr_repository.app.repository_url
}

output "service_arn" {
  description = "Express Mode service ARN, or null during repository/database bootstrap."
  value       = one(aws_ecs_express_gateway_service.app[*].service_arn)
}

output "service_ingress_paths" {
  description = "AWS-generated service endpoints and their access types."
  value       = var.deploy_service ? aws_ecs_express_gateway_service.app[0].ingress_paths : []
}

output "database_endpoint" {
  description = "Aurora PostgreSQL writer endpoint."
  value       = aws_rds_cluster.database.endpoint
}

output "database_port" {
  description = "PostgreSQL port."
  value       = aws_rds_cluster.database.port
}

output "database_admin_secret_arn" {
  description = "RDS-managed admin secret ARN; the password is not read by Terraform."
  value       = aws_rds_cluster.database.master_user_secret[0].secret_arn
}

output "application_security_group_id" {
  description = "Security group allowed to connect to PostgreSQL."
  value       = aws_security_group.app.id
}
