variable "name" {
  description = "Resource name prefix, unique within the account and region."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,29}[a-z0-9]$", var.name))
    error_message = "Use 3-31 lowercase letters, digits, or hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "vpc_id" {
  description = "Existing VPC containing the application and database subnets."
  type        = string
}

variable "private_subnet_ids" {
  description = "At least two existing private subnets in distinct Availability Zones, with NAT or the necessary VPC endpoints."
  type        = list(string)

  validation {
    condition     = length(distinct(var.private_subnet_ids)) >= 2
    error_message = "Provide at least two distinct private subnet IDs."
  }
}

variable "database_engine_version" {
  description = "Aurora PostgreSQL version supporting Serverless v2 in the selected AWS region."
  type        = string
}

variable "database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "myapp"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,62}$", var.database_name))
    error_message = "The database name must be 1-63 alphanumeric characters, starting with a letter."
  }
}

variable "database_instance_count" {
  description = "Number of Aurora Serverless v2 instances; two provides a writer and failover reader."
  type        = number
  default     = 2

  validation {
    condition     = var.database_instance_count >= 1 && var.database_instance_count <= 3 && floor(var.database_instance_count) == var.database_instance_count
    error_message = "Use an integer from 1 to 3."
  }
}

variable "deploy_service" {
  description = "Enable after pushing the selected container image to the ECR repository."
  type        = bool
  default     = false
}

variable "container_image_tag" {
  description = "Existing immutable ECR image tag to deploy, for example the Azure DevOps build ID."
  type        = string
  default     = "initial"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$", var.container_image_tag))
    error_message = "Provide a valid container image tag, up to 128 characters."
  }
}

variable "tags" {
  description = "Tags applied to managed resources."
  type        = map(string)
  default     = {}
}
