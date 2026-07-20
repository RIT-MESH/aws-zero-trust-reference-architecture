variable "name_prefix" {
  description = "Prefix for CloudTrail resources."
  type        = string
  default     = "zt"
}

variable "trail_bucket_name" {
  description = "S3 bucket name for CloudTrail log delivery."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt CloudTrail log files."
  type        = string
}

variable "enable_log_file_validation" {
  description = "Enable CloudTrail log file integrity validation."
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Include global service events (IAM) in the trail."
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Make the trail a multi-region trail (recommended)."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Stream CloudTrail events to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention for the CloudTrail CloudWatch log group."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
