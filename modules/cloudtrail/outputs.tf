output "trail_arn" {
  description = "ARN of the CloudTrail."
  value       = aws_cloudtrail.this.arn
}

output "trail_name" {
  description = "Name of the CloudTrail."
  value       = aws_cloudtrail.this.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for CloudTrail (null if disabled)."
  value       = length(aws_cloudwatch_log_group.trail) > 0 ? aws_cloudwatch_log_group.trail[0].name : null
}
