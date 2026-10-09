variable "aws_region" {
  description = "AWS region containing the existing VPC."
  type        = string
}

variable "name" {
  description = "Unique resource name prefix."
  type        = string
  default     = "myapp"
}

variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs across at least two Availability Zones."
  type        = list(string)
}

variable "database_engine_version" {
  description = "Region-supported Aurora PostgreSQL Serverless v2 engine version."
  type        = string
}

variable "deploy_service" {
  description = "Set true only after pushing the selected image to ECR."
  type        = bool
  default     = false
}

variable "container_image_tag" {
  description = "Immutable ECR tag to deploy, matching the pipeline build ID."
  type        = string
  default     = "initial"
}
