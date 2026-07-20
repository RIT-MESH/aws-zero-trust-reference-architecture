variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resources in this example."
  type        = string
  default     = "zt-lab"
}

variable "vpc_cidr" {
  description = "VPC CIDR (RFC1918)."
  type        = string
  default     = "10.30.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs (lab still uses two AZs for subnets; single NAT GW keeps cost low)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB. Placeholder."
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

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default = {
    environment = "lab"
  }
}
