variable "name_prefix" {
  description = "Prefix for the logging bucket name."
  type        = string
  default     = "zt-logging"
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the logging bucket. Use the KMS module 's3' or 'logs' key."
  type        = string
}

variable "force_destroy" {
  description = "Allow the bucket to be destroyed even when non-empty. Set false in production."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days to retain noncurrent object versions before expiration."
  type        = number
  default     = 90
}

variable "log_access_logging" {
  description = "Enable server-side access logging on the logging bucket itself (logged to a sub-prefix)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
