output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = var.vpc_cidr
}

output "vpc_main_route_table_id" {
  description = "ID of the VPC main route table."
  value       = aws_vpc.this.main_route_table_id
}

output "public_subnet_ids" {
  description = "Map of AZ -> public subnet ID."
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_app_subnet_ids" {
  description = "Map of AZ -> private application subnet ID."
  value       = { for k, v in aws_subnet.private_app : k => v.id }
}

output "isolated_data_subnet_ids" {
  description = "Map of AZ -> isolated data subnet ID."
  value       = { for k, v in aws_subnet.isolated_data : k => v.id }
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "app_route_table_ids" {
  description = "Map of AZ -> private application route table ID."
  value       = { for k, v in aws_route_table.app : k => v.id }
}

output "data_route_table_id" {
  description = "ID of the isolated data route table."
  value       = aws_route_table.data.id
}

output "nat_gateway_ips" {
  description = "Map of AZ -> NAT Gateway public IP (for reference/debugging only)."
  value       = { for k, v in aws_eip.nat : k => v.public_ip }
}

output "interface_endpoint_sg_id" {
  description = "Security group ID for interface endpoints (allow HTTPS from VPC)."
  value       = length(aws_security_group.endpoint) > 0 ? aws_security_group.endpoint[0].id : null
}

output "vpc_endpoint_ids" {
  description = "Map of interface endpoint service name -> endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint."
  value       = aws_vpc_endpoint.s3_gateway.id
}

output "flow_log_cloudwatch_log_group" {
  description = "CloudWatch log group name for VPC flow logs."
  value       = length(aws_cloudwatch_log_group.flow_logs) > 0 ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
