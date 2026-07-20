# Native Terraform test for the network module. Uses a mock provider so it runs
# without AWS credentials and without applying any resources.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
}

variables {
  vpc_name           = "zt-test"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  single_nat_gateway = true
  enable_flow_logs   = true
}

run "private_and_data_subnets_have_no_public_ip" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.private_app : s.map_public_ip_on_launch == false])
    error_message = "Private application subnets must not map public IPs"
  }

  assert {
    condition     = alltrue([for s in aws_subnet.isolated_data : s.map_public_ip_on_launch == false])
    error_message = "Isolated data subnets must not map public IPs"
  }
}

run "flow_logs_are_enabled" {
  command = plan

  assert {
    condition     = length(aws_flow_log.cloudwatch) == 1
    error_message = "VPC Flow Logs to CloudWatch must be enabled"
  }
}

run "s3_gateway_endpoint_exists" {
  command = plan

  assert {
    condition     = aws_vpc_endpoint.s3_gateway.vpc_endpoint_type == "Gateway"
    error_message = "An S3 gateway VPC endpoint must exist"
  }
}
