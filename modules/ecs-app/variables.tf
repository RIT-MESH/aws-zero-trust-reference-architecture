variable "name_prefix" {
  description = "Prefix for ECS resources."
  type        = string
  default     = "zt"
}

variable "subnet_ids" {
  description = "Private application subnet IDs for the ECS service."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Application tier security group ID (created by the edge module). The service uses this SG."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN to register Fargate tasks with."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "container_image" {
  description = "Container image URI. Use a placeholder ECR URI in examples; replace with your own image."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/zt-app:replace-me"
}

variable "task_cpu" {
  description = "CPU units for the Fargate task."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory (MiB) for the Fargate task."
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of Fargate tasks."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum capacity for autoscaling."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum capacity for autoscaling."
  type        = number
  default     = 6
}

variable "cpu_target_value" {
  description = "Target CPU utilization for autoscaling."
  type        = number
  default     = 60
}

variable "log_group_name" {
  description = "CloudWatch log group name for container logs."
  type        = string
  default     = "/aws/ecs/zt-app"
}

variable "log_retention_days" {
  description = "Retention (days) for container logs."
  type        = number
  default     = 365
}

variable "secrets_kms_key_arn" {
  description = "KMS key ARN used by the task execution role to decrypt Secrets Manager secrets."
  type        = string
  default     = ""
}

variable "log_kms_key_arn" {
  description = "KMS key ARN used to encrypt the container CloudWatch log group. Empty disables CMK encryption."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
