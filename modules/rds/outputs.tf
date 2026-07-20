output "db_instance_id" {
  description = "ID of the RDS instance."
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "Write endpoint of the RDS instance."
  value       = aws_db_instance.this.address
}

output "db_security_group_id" {
  description = "Security group ID of the database."
  value       = aws_security_group.db.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}

output "db_master_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret holding the master credentials (value never output)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
