variable "name_prefix" {
  description = "Prefix for KMS key aliases and related resources."
  type        = string
  default     = "zt"
}

variable "enable_key_rotation" {
  description = "Enable automatic annual rotation of customer-managed KMS keys."
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "Waiting period before KMS keys are deleted after key removal from Terraform."
  type        = number
  default     = 30
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "administrator_principals" {
  description = "List of IAM principal ARNs permitted to administer the keys. Use placeholders; never embed real account admins."
  type        = list(string)
  default     = ["arn:aws:iam::123456789012:root"]
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
