output "config_recorder_name" {
  description = "Name of the AWS Config recorder."
  value       = aws_config_configuration_recorder.this.name
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector (null if disabled)."
  value       = length(aws_guardduty_detector.this) > 0 ? aws_guardduty_detector.this[0].id : null
}

output "security_hub_arn" {
  description = "ARN of the Security Hub account resource (null if disabled)."
  value       = length(aws_securityhub_account.this) > 0 ? aws_securityhub_account.this[0].arn : null
}

output "inspector_account_ids" {
  description = "Account IDs where Inspector v2 is enabled (empty if disabled)."
  value       = length(aws_inspector2_enabler.this) > 0 ? aws_inspector2_enabler.this[0].account_ids : []
}

output "config_sns_topic_arn" {
  description = "SNS topic ARN for Config/finding notifications."
  value       = aws_sns_topic.config.arn
}
