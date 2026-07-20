output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = module.edge.alb_dns_name
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.app.cluster_id
}

output "db_endpoint" {
  description = "RDS write endpoint."
  value       = module.db.db_endpoint
}

output "db_master_secret_arn" {
  description = "Secrets Manager ARN for DB credentials (value not exposed)."
  value       = module.db.db_master_secret_arn
  sensitive   = true
}

output "cloudtrail_name" {
  description = "CloudTrail name."
  value       = module.cloudtrail.trail_name
}

output "break_glass_role_arn" {
  description = "Break-glass role ARN (MFA-gated, no permanent credential)."
  value       = module.iam.break_glass_role_arn
}
