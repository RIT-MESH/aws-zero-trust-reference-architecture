variable "vpc_cidr" {
  description = "CIDR block for the VPC. Use a placeholder/private range in examples."
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(regex("^10\\.|^172\\.(1[6-9]|2[0-9]|3[01])\\.|^192\\.168\\.", var.vpc_cidr))
    error_message = "vpc_cidr must be an RFC1918 private range (10.x, 172.16-31.x, or 192.168.x)."
  }
}

variable "vpc_name" {
  description = "Name prefix for the VPC and related resources."
  type        = string
  default     = "zt-vpc"
}

variable "availability_zones" {
  description = "List of exactly two Availability Zones to use for the HA design."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "This reference architecture is a fixed two-AZ HA design; provide exactly two AZs."
  }
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs and S3."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (lower-cost labs). Set false for one NAT GW per AZ in production."
  type        = bool
  default     = true
}

variable "flow_log_kms_key_arn" {
  description = "KMS key ARN used to encrypt flow log S3 objects. Pass from the KMS module."
  type        = string
  default     = ""
}

variable "flow_log_bucket_arn" {
  description = "Existing S3 bucket ARN for VPC Flow Logs. If empty, one is created by the s3-logging module."
  type        = string
  default     = ""
}

variable "flow_log_bucket_prefix" {
  description = "S3 key prefix for VPC Flow Logs."
  type        = string
  default     = "vpc-flow-logs/"
}

variable "enable_interface_endpoints" {
  description = "Create private interface VPC endpoints for supported AWS services."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
