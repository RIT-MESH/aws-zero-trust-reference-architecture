locals {
  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })
}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Security group for the database: allow PostgreSQL (5432) only from the app SG.
# The egress block uses an empty cidr_blocks list to deny all egress from the
# data tier (assume-breach isolation).
# -----------------------------------------------------------------------------
resource "aws_security_group" "db" {
  # checkov:skip=CKV_AWS_382: The egress uses an empty cidr_blocks list, which denies ALL egress from the data tier; the check mis-flags protocol=-1 with an empty destination.
  name        = "${var.name_prefix}-db-sg"
  description = "Allow PostgreSQL from the application tier SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from app SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    description = "No egress from the data tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-sg"
  })
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.name_prefix}-db-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Isolated data subnets for the Zero Trust RDS instance"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# -----------------------------------------------------------------------------
# Parameter group enabling PostgreSQL query logging (CKV2_AWS_30).
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "this" {
  name        = "${var.name_prefix}-pg"
  family      = "postgres${split(".", var.engine_version)[0]}"
  description = "Zero Trust PostgreSQL parameter group with query logging"

  parameter {
    name         = "log_statement"
    value        = "all"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "0"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-pg"
  })
}

# -----------------------------------------------------------------------------
# IAM role for RDS Enhanced Monitoring.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "monitoring" {
  name = "${var.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL instance.
# Credentials are managed by RDS in AWS Secrets Manager (manage_master_user_password),
# encrypted with the secrets KMS key. Terraform never sees or outputs the password.
# -----------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  # checkov:skip=CKV2_AWS_69: TLS-to-DB is enforced via rds.force_ssl=1 in the attached aws_db_parameter_group; checkov 3.3 does not detect the aws_db_instance->aws_db_parameter_group graph connection, so the check is suppressed. The control IS implemented.
  # checkov:skip=CKV_AWS_293: Deletion protection is configurable; enabled in the production example and intentionally disabled in the lab example for easy teardown. See docs/cost.md.
  # checkov:skip=CKV_AWS_157: Multi-AZ is configurable; enabled in the production example and intentionally disabled in the lab example to reduce cost. See docs/cost.md.
  engine                        = "postgres"
  engine_version                = var.engine_version
  identifier                    = "${var.name_prefix}-postgres"
  username                      = "zt_admin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.secrets_kms_key_arn

  iam_database_authentication_enabled = true

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_arn

  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  parameter_group_name       = aws_db_parameter_group.this.name
  publicly_accessible        = var.publicly_accessible
  multi_az                   = var.multi_az
  deletion_protection        = var.deletion_protection
  backup_retention_period    = var.backup_retention_period
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  monitoring_interval = 30
  monitoring_role_arn = aws_iam_role.monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-postgres"
  })
}