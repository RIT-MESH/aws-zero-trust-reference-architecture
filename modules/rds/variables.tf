variable "name_prefix" {
  description = "Prefix for RDS resources."
  type        = string
  default     = "zt"
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated data subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID of the application tier. The DB SG allows traffic only from this SG."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.2"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.m6g.large"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 50
}

variable "multi_az" {
  description = "Enable Multi-AZ for the database (production default)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable RDS deletion protection."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number
  default     = 14
  validation {
    condition     = var.backup_retention_period >= 7 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 7 and 35 days."
  }
}

variable "storage_encrypted" {
  description = "Encrypt RDS storage with a customer-managed KMS key."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for RDS storage encryption."
  type        = string
}

variable "secrets_kms_key_arn" {
  description = "KMS key ARN used to encrypt the DB master credentials secret in Secrets Manager."
  type        = string
}

variable "publicly_accessible" {
  description = "Must remain false. Included only so tests can assert it."
  type        = bool
  default     = false
  validation {
    condition     = var.publicly_accessible == false
    error_message = "publicly_accessible must be false (Zero Trust: no public DB access)."
  }
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
