provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      project    = "aws-zero-trust-reference-architecture"
      managed_by = "terraform"
      example    = "production"
    })
  }

  # Offline validation only. These skips disable AWS credential, metadata, and
  # account-id checks so Terraform can init and validate with fake placeholder
  # credentials and no AWS API calls. They do NOT make terraform plan/apply
  # work offline (data sources still require AWS); never run plan/apply with the
  # dummy credentials. See scripts/offline-env.sh and the README.
  skip_credentials_validation = var.offline_validation
  skip_metadata_api_check     = var.offline_validation
  skip_requesting_account_id  = var.offline_validation
}

# -----------------------------------------------------------------------------
# KMS keys (customer-managed) for logs, rds, secrets, s3, cloudtrail
# -----------------------------------------------------------------------------
module "kms" {
  source = "../../modules/kms"

  name_prefix             = var.name_prefix
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = var.tags
}

# -----------------------------------------------------------------------------
# Centralized S3 logging bucket (CloudTrail, flow logs, ALB, WAF)
# -----------------------------------------------------------------------------
module "logging_bucket" {
  source = "../../modules/s3-logging"

  name_prefix = "${var.name_prefix}-logs"
  kms_key_arn = module.kms.key_arns["s3"]
  tags        = var.tags
}

# -----------------------------------------------------------------------------
# CloudTrail (encrypted, multi-region, log file validation, insights)
# -----------------------------------------------------------------------------
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  name_prefix            = var.name_prefix
  trail_bucket_arn       = module.logging_bucket.bucket_arn
  trail_bucket_name      = module.logging_bucket.bucket_name
  kms_key_arn            = module.kms.key_arns["cloudtrail"]
  enable_cloudwatch_logs = true
  log_retention_days     = 365
  tags                   = var.tags
}

# -----------------------------------------------------------------------------
# Network foundation (VPC, subnets, route tables, flow logs, endpoints)
# -----------------------------------------------------------------------------
module "network" {
  source = "../../modules/network"

  vpc_name             = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  single_nat_gateway   = false # One NAT GW per AZ in production
  enable_flow_logs     = true
  flow_log_bucket_arn  = module.logging_bucket.bucket_arn
  flow_log_kms_key_arn = module.kms.key_arns["logs"]
  tags                 = var.tags
}

# -----------------------------------------------------------------------------
# Edge: WAF + ALB + HTTPS/redirect listeners + app target group + app SG
# -----------------------------------------------------------------------------
module "edge" {
  source = "../../modules/edge"

  name_prefix                = var.name_prefix
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = values(module.network.public_subnet_ids)
  app_target_port            = 8080
  health_check_path          = "/health"
  allowed_ingress_cidrs      = var.allowed_ingress_cidrs
  certificate_arn            = var.certificate_arn
  enable_waf                 = true
  rate_based_rule_threshold  = 2000
  enable_ip_reputation_rules = true
  access_log_bucket_arn      = module.logging_bucket.bucket_arn
  access_log_prefix          = "alb/"
  tags                       = var.tags
}

# -----------------------------------------------------------------------------
# ECS Fargate application tier (private subnets, no public IP, least privilege)
# -----------------------------------------------------------------------------
module "app" {
  source = "../../modules/ecs-app"

  name_prefix           = var.name_prefix
  vpc_id                = module.network.vpc_id
  subnet_ids            = values(module.network.private_app_subnet_ids)
  app_security_group_id = module.edge.app_security_group_id
  target_group_arn      = module.edge.target_group_arn
  container_port        = 8080
  container_image       = var.container_image
  desired_count         = 3
  min_capacity          = 3
  max_capacity          = 12
  cpu_target_value      = 60
  log_retention_days    = 365
  secrets_kms_key_arn   = module.kms.key_arns["secrets"]
  log_kms_key_arn       = module.kms.key_arns["logs"]
  tags                  = var.tags
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL (isolated data subnets, multi-AZ, CMK encryption, Secrets Manager)
# -----------------------------------------------------------------------------
module "db" {
  source = "../../modules/rds"

  name_prefix             = var.name_prefix
  vpc_id                  = module.network.vpc_id
  subnet_ids              = values(module.network.isolated_data_subnet_ids)
  app_security_group_id   = module.edge.app_security_group_id
  multi_az                = true
  deletion_protection     = true
  backup_retention_period = 14
  instance_class          = var.db_instance_class
  kms_key_arn             = module.kms.key_arns["rds"]
  secrets_kms_key_arn     = module.kms.key_arns["secrets"]
  tags                    = var.tags
}

# -----------------------------------------------------------------------------
# Security services: Config, GuardDuty, Security Hub, Inspector
# -----------------------------------------------------------------------------
module "security" {
  source = "../../modules/security-services"

  name_prefix           = var.name_prefix
  config_log_bucket_arn = module.logging_bucket.bucket_arn
  config_kms_key_arn    = module.kms.key_arns["logs"]
  enable_guardduty      = true
  enable_security_hub   = true
  enable_inspector      = true
  tags                  = var.tags
}

# -----------------------------------------------------------------------------
# IAM: break-glass role + workload permission boundary
# -----------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  name_prefix                  = var.name_prefix
  max_session_duration_seconds = 3600
  tags                         = var.tags
}
