output "bucket_id" {
  description = "ID (name) of the logging bucket."
  value       = aws_s3_bucket.logs.id
}

output "bucket_arn" {
  description = "ARN of the logging bucket."
  value       = aws_s3_bucket.logs.arn
}

output "bucket_name" {
  description = "Name of the logging bucket."
  value       = aws_s3_bucket.logs.id
}
