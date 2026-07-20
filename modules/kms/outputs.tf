output "key_arns" {
  description = "Map of logical key name -> KMS key ARN."
  value       = { for k, v in aws_kms_key.this : k => v.arn }
}

output "key_ids" {
  description = "Map of logical key name -> KMS key ID."
  value       = { for k, v in aws_kms_key.this : k => v.key_id }
}

output "aliases" {
  description = "Map of logical key name -> alias name."
  value       = { for k, v in aws_kms_alias.this : k => v.name }
}
