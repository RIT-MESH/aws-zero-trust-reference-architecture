provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      project    = "aws-zero-trust-reference-architecture"
      managed_by = "terraform"
      example    = "lab"
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

# Lab = cost-sensitive: single NAT GW, smaller RDS, single-AZ DB, fewer tasks.
module "kms" {
  source = "../../modules/kms"

  name_prefix             = var.name_prefix
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags
}

module "logging_bucket" {
  source = "../../modules/s3-logging"

  name_prefix = "${var.name_prefix}-logs"
  kms_key_arn = module.kms.key_arns["s3"]
  tags        = var.tags
}

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

module "network" {
  source = "../../modules/network"

  vpc_name             = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  single_nat_gateway   = true # Lower cost: one shared NAT Gateway
  enable_flow_logs     = true
  flow_log_bucket_arn  = module.logging_bucket.bucket_arn
  flow_log_kms_key_arn = module.kms.key_arns["logs"]
  tags                 = var.tags
}

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
  enable_deletion_protection = false
  rate_based_rule_threshold  = 1000
  enable_ip_reputation_rules = false # Skip extra managed rule groups to reduce cost/overhead
  access_log_bucket_arn      = module.logging_bucket.bucket_arn
  access_log_prefix          = "alb/"
  tags                       = var.tags
}

module "app" {
  source = "../../modules/ecs-app"

  name_prefix           = var.name_prefix
  vpc_id                = module.network.vpc_id
  subnet_ids            = values(module.network.private_app_subnet_ids)
  app_security_group_id = module.edge.app_security_group_id
  target_group_arn      = module.edge.target_group_arn
  container_port        = 8080
  container_image       = var.container_image
  task_cpu              = 256
  task_memory           = 512
  desired_count         = 1
  min_capacity          = 1
  max_capacity          = 3
  log_retention_days    = 365
  secrets_kms_key_arn   = module.kms.key_arns["secrets"]
  log_kms_key_arn       = module.kms.key_arns["logs"]
  tags                  = var.tags
}

module "db" {
  source = "../../modules/rds"

  name_prefix             = var.name_prefix
  vpc_id                  = module.network.vpc_id
  subnet_ids              = values(module.network.isolated_data_subnet_ids)
  app_security_group_id   = module.edge.app_security_group_id
  multi_az                = false # Single-AZ to reduce lab cost
  deletion_protection     = false # Easier lab teardown
  backup_retention_period = 7
  instance_class          = "db.t4g.small"
  kms_key_arn             = module.kms.key_arns["rds"]
  secrets_kms_key_arn     = module.kms.key_arns["secrets"]
  tags                    = var.tags
}

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

module "iam" {
  source = "../../modules/iam"

  name_prefix                  = var.name_prefix
  max_session_duration_seconds = 3600
  tags                         = var.tags
}
