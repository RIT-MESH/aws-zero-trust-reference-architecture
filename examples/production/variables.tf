variable "aws_region" {
  description = "AWS region. Placeholder default; override via TF_VAR_aws_region."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in tags and naming."
  type        = string
  default     = "prod"
}

variable "name_prefix" {
  description = "Prefix for all resources in this example."
  type        = string
  default     = "zt-prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR (RFC1918)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs for the HA design."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB. Placeholder corporate egress range."
  type        = list(string)
  default     = ["203.0.113.0/24"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Replace with your real cert ARN before use."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/replace-with-real-cert-arn"
}

variable "container_image" {
  description = "ECR image URI serving /health. Placeholder; replace with your image."
  type        = string
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/zt-app:replace-me"
}

variable "db_instance_class" {
  description = "RDS instance class (production)."
  type        = string
  default     = "db.m6g.large"
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default = {
    environment = "prod"
    cost_center = "security-platform"
  }
}

variable "offline_validation" {
  description = "Disable AWS credential, metadata, region, and account checks during offline validation."
  type        = bool
  default     = false
}
