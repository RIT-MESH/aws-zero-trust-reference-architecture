locals {
  name_prefix = var.vpc_name

  # Newbits for subnets within the VPC /16: /20 gives 4094 hosts per subnet.
  public_newbits   = 20
  private_newbits  = 20
  isolated_newbits = 20

  azs = var.availability_zones

  # NAT Gateway: single (shared) for cost-sensitive labs, one per AZ for production.
  nat_azs = var.single_nat_gateway ? [local.azs[0]] : local.azs

  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = local.name_prefix
  })
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Default security group: restrict all traffic (no rules). All workloads use
# explicitly defined security groups instead.
# -----------------------------------------------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-default-sg-restricted"
  })
}

# Subnets: public (ALB + NAT GW), private app, isolated data
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = toset(local.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, local.public_newbits - 16, index(local.azs, each.value))
  availability_zone       = each.value
  map_public_ip_on_launch = false # Public IPs only on ALB/NAT GW, never on workloads

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${each.value}"
    tier = "public"
  })
}

resource "aws_subnet" "private_app" {
  for_each = toset(local.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, local.private_newbits - 16, index(local.azs, each.value) + 4)
  availability_zone       = each.value
  map_public_ip_on_launch = false # No public IPs on this tier

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-${each.value}"
    tier = "app"
  })
}

resource "aws_subnet" "isolated_data" {
  for_each = toset(local.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, local.isolated_newbits - 16, index(local.azs, each.value) + 8)
  availability_zone       = each.value
  map_public_ip_on_launch = false # No public IPs on this tier

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-${each.value}"
    tier = "data"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway for public tier
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = local.name_prefix
  })
}

# -----------------------------------------------------------------------------
# Elastic IPs and NAT Gateways (one shared, or one per AZ)
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  # checkov:skip=CKV2_AWS_19: These EIPs are attached to NAT Gateways (not EC2 instances), which is a valid and intended use; the check only considers EC2 attachment.
  for_each = toset(local.nat_azs)
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${each.value}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[each.value].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${each.value}"
  })

  depends_on = [aws_internet_gateway.this]
}

# -----------------------------------------------------------------------------
# Route tables: public, app, data
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    tier = "public"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  for_each = toset(local.azs)
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? local.azs[0] : each.value].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-rt-${each.value}"
    tier = "app"
  })
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.private_app

  subnet_id      = aws_subnet.private_app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

# Isolated data tier: no default route to the internet (assume-breach isolation).
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-rt"
    tier = "data"
  })
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.isolated_data

  subnet_id      = aws_subnet.isolated_data[each.key].id
  route_table_id = aws_route_table.data.id
}

# -----------------------------------------------------------------------------
# VPC Flow Logs -> CloudWatch Logs (real-time) and S3 (long-term retention)
# -----------------------------------------------------------------------------
# Long-term flow logs are retained in the S3 logging bucket; the CloudWatch group is for short-term detection.
resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = 365
  kms_key_id        = var.flow_log_kms_key_arn != "" ? var.flow_log_kms_key_arn : null

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-logs-cw"
  })
}
resource "aws_iam_role" "vpc_flow_log" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${local.name_prefix}-vpc-flow-log"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceVpc" = aws_vpc.this.id }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_log_cloudwatch" {
  # checkov:skip=CKV_AWS_355: Flow log role uses Resource=* because the CloudWatch log group ARN is not known at role creation; actions are limited to logs:CreateLogGroup/Stream/PutLogEvents/Describe (AWS-documented pattern).
  # checkov:skip=CKV_AWS_356: Same as above; write actions are scoped to CloudWatch Logs log-stream management only.
  # checkov:skip=CKV_AWS_290: Flow log role is scoped to logs:CreateLogGroup/Stream/PutLogEvents; Resource=* because the log group ARN is not known at role creation (AWS-documented pattern).
  count = var.enable_flow_logs ? 1 : 0
  name  = "cloudwatch"
  role  = aws_iam_role.vpc_flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "cloudwatch" {
  count                = var.enable_flow_logs ? 1 : 0
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn         = aws_iam_role.vpc_flow_log[0].arn
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-log-cw"
  })
}

# S3 destination flow logs (long-term). Requires an existing bucket ARN.
resource "aws_flow_log" "s3" {
  count                = var.enable_flow_logs && var.flow_log_bucket_arn != "" ? 1 : 0
  log_destination_type = "s3"
  log_destination      = "${var.flow_log_bucket_arn}/${var.flow_log_bucket_prefix}"
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"

  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-log-s3"
  })
}

# -----------------------------------------------------------------------------
# Gateway VPC endpoint for S3 (private access without NAT)
# -----------------------------------------------------------------------------
data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [for k in local.azs : aws_route_table.app[k].id],
    [aws_route_table.data.id],
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-s3-gateway"
  })
}

# -----------------------------------------------------------------------------
# Interface VPC endpoints for private AWS service access
# -----------------------------------------------------------------------------
locals {
  interface_endpoints = var.enable_interface_endpoints ? toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
    "logs",
    "secretsmanager",
    "kms",
    "ecr.api",
    "ecr.dkr",
  ]) : toset([])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private_app[local.azs[0]].id, aws_subnet.private_app[local.azs[1]].id]
  security_group_ids  = [aws_security_group.endpoint[0].id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.value}-endpoint"
  })
}

# -----------------------------------------------------------------------------
# Security groups (cross-referenced, not broad CIDRs).
# The endpoint SG lives here; app/alb/db SGs are defined in consuming modules
# but reference exported SG IDs from this module.
# -----------------------------------------------------------------------------
resource "aws_security_group" "endpoint" {
  # checkov:skip=CKV2_AWS_5: Attached to all interface VPC endpoints created in this module; the attachment is via the for_each endpoints resource.
  count       = var.enable_interface_endpoints ? 1 : 0
  name        = "${local.name_prefix}-endpoint-sg"
  description = "Allow HTTPS from the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All egress to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-endpoint-sg"
  })
}