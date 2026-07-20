output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the ALB."
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group ID of the application tier (owned here; consumed by ecs-app and rds)."
  value       = aws_security_group.app.id
}

output "target_group_arn" {
  description = "ARN of the application target group (attach ECS tasks here)."
  value       = aws_lb_target_group.app.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener."
  value       = aws_lb_listener.https.arn
}

output "web_acl_arn" {
  description = "ARN of the WAF web ACL (null if WAF disabled)."
  value       = length(aws_wafv2_web_acl.this) > 0 ? aws_wafv2_web_acl.this[0].arn : null
}
