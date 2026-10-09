output "ecr_repository_url" {
  value = module.app.ecr_repository_url
}

output "service_arn" {
  value = module.app.service_arn
}

output "service_ingress_paths" {
  value = module.app.service_ingress_paths
}

output "database_endpoint" {
  value = module.app.database_endpoint
}

output "database_admin_secret_arn" {
  value = module.app.database_admin_secret_arn
}
