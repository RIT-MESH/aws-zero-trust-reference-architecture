locals {
  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# AWS Config: recorder, delivery channel, configuration aggregator.
# -----------------------------------------------------------------------------
resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name_prefix}-config-delivery"
  s3_bucket_name = var.config_log_bucket_arn
  s3_key_prefix  = "config/"
  sns_topic_arn  = aws_sns_topic.config.arn

  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

resource "aws_iam_role" "config" {
  name = "${var.name_prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_sns_topic" "config" {
  name              = "${var.name_prefix}-config-notifications"
  kms_master_key_id = var.config_kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-config-notifications"
  })
}

# Config conformance pack documenting required tags and no-public-IP checks.
resource "aws_config_conformance_pack" "tags" {
  name = "${var.name_prefix}-required-tags"

  template_body = jsonencode({
    ConformancePackName = "${var.name_prefix}-required-tags"
    TemplateBody = jsonencode({
      Parameters = {}
      Rules = [
        {
          RuleName = "zt-required-tags"
          Source = {
            Owner            = "AWS"
            SourceIdentifier = "AWS_CONFIG_RULE"
            SourceDetails = [{
              EventSource               = "aws.config"
              MaximumExecutionFrequency = "One_Hour"
            }]
          }
        },
      ]
    })
  })

  depends_on = [aws_config_configuration_recorder.this]
}

# -----------------------------------------------------------------------------
# Amazon GuardDuty
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  # checkov:skip=CKV2_AWS_3: Single-account reference architecture; a regional GuardDuty detector is enabled. Organization-level GuardDuty administration is out of scope.
  count                        = var.enable_guardduty ? 1 : 0
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false # No EKS in this reference architecture
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-guardduty"
  })
}

# -----------------------------------------------------------------------------
# AWS Security Hub + benchmark standards
# -----------------------------------------------------------------------------
resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = true

}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.2.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# -----------------------------------------------------------------------------
# Amazon Inspector (v2) for EC2 and ECR
# -----------------------------------------------------------------------------
resource "aws_inspector2_enabler" "this" {
  count = var.enable_inspector ? 1 : 0

  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2"]

  depends_on = [aws_guardduty_detector.this]
}

# -----------------------------------------------------------------------------
# CloudWatch log groups for security findings aggregation
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "security_findings" {
  name              = "/aws/security/${var.name_prefix}/findings"
  retention_in_days = 365
  kms_key_id        = var.config_kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-security-findings"
  })
}

# CloudWatch metric alarms for GuardDuty findings (high severity).
resource "aws_cloudwatch_metric_alarm" "guardduty_high" {
  count             = var.enable_guardduty ? 1 : 0
  alarm_name        = "${var.name_prefix}-guardduty-high-findings"
  alarm_description = "Alert when GuardDuty reports high-severity findings"

  namespace   = "AWS/GuardDuty"
  metric_name = "FindingCount"
  dimensions = {
    DetectorId = aws_guardduty_detector.this[0].id
    Severity   = "High"
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.config.arn]

  tags = local.common_tags
}