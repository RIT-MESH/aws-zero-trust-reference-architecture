variable "name_prefix" {
  description = "Prefix for security service resources."
  type        = string
  default     = "zt"
}

variable "config_log_bucket_arn" {
  description = "S3 bucket ARN for AWS Config recorder delivery."
  type        = string
}

variable "config_kms_key_arn" {
  description = "KMS key ARN used by AWS Config to encrypt delivery."
  type        = string
}

variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty detectors."
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub and subscribe to benchmark standards."
  type        = bool
  default     = true
}

variable "enable_inspector" {
  description = "Enable Amazon Inspector (v2) for EC2 and ECR scanning."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
