variable "name_prefix" {
  description = "Prefix for edge resources (ALB, WAF, target group)."
  type        = string
  default     = "zt"
}

variable "vpc_id" {
  description = "VPC ID where the ALB is deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB."
  type        = list(string)
}

variable "app_target_protocol" {
  description = "Protocol used by the application targets behind the ALB."
  type        = string
  default     = "HTTP"
}

variable "app_target_port" {
  description = "Port used by the application targets behind the ALB."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ALB health check path for the application targets."
  type        = string
  default     = "/health"
}

variable "allowed_ingress_cidrs" {
  description = "List of CIDR blocks allowed to reach the ALB on 80/443. Use placeholder corporate egress ranges."
  type        = list(string)
  default     = ["203.0.113.0/24"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Pass a placeholder ARN in examples; the real value comes from your own ACM cert."
  type        = string
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/replace-with-real-cert-arn"
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection. Set false only for cost-sensitive labs that need easy teardown."
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Attach an AWS WAF web ACL with managed rule groups and a rate-based rule to the ALB."
  type        = bool
  default     = true
}

variable "rate_based_rule_threshold" {
  description = "Per-IP request threshold per 5 minutes for the WAF rate-based rule."
  type        = number
  default     = 2000
}

variable "enable_ip_reputation_rules" {
  description = "Enable AWSManagedRulesAmazonIpReputationList and AWSManagedRulesAnonymousIpList managed rule groups."
  type        = bool
  default     = true
}

variable "access_log_bucket_arn" {
  description = "S3 bucket ARN (and prefix) for ALB access logs. Set to empty to disable ALB access logging."
  type        = string
  default     = ""
}

variable "access_log_prefix" {
  description = "S3 key prefix for ALB access logs."
  type        = string
  default     = "alb/"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}