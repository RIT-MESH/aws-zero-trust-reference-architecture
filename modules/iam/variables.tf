variable "name_prefix" {
  description = "Prefix for IAM resources."
  type        = string
  default     = "zt"
}

variable "break_glass_trusted_principals" {
  description = "IAM principal ARNs allowed to assume the break-glass role with MFA. Use placeholder ARNs."
  type        = list(string)
  default     = ["arn:aws:iam::123456789012:role/IdentityCenterBreakGlass"]
}

variable "max_session_duration_seconds" {
  description = "Maximum session duration for the break-glass role."
  type        = number
  default     = 3600
  validation {
    condition     = var.max_session_duration_seconds <= 7200
    error_message = "Keep break-glass session durations short (<= 7200s)."
  }
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
