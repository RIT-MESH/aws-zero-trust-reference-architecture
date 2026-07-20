locals {
  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })
}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# SNS topic for CloudTrail notifications
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "trail" {
  name              = "${var.name_prefix}-cloudtrail-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-cloudtrail-notifications"
  })
}

# -----------------------------------------------------------------------------
# CloudWatch log group + role for CloudTrail delivery
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "trail" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-cloudtrail-logs"
  })
}

resource "aws_iam_role" "trail_to_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.name_prefix}-cloudtrail-to-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

# CloudTrail -> CloudWatch Logs. The log group ARN is not known at role-creation
# time, so the role is scoped to logs:CreateLogStream/PutLogEvents on the group.
resource "aws_iam_role_policy" "trail_to_cloudwatch" {
  # checkov:skip=CKV_AWS_290: Log group ARN is unknown at role creation; actions are limited to log stream writes on the trail log group.
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "logs"
  role  = aws_iam_role.trail_to_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.trail[0].arn}:*"
    }]
  })
}

# -----------------------------------------------------------------------------
# CloudTrail: encrypted, log-file validation, multi-region, global events,
# CloudWatch Logs integration, SNS notifications, and Insights.
# -----------------------------------------------------------------------------
resource "aws_cloudtrail" "this" {
  # checkov:skip=CKV2_AWS_10: CloudWatch Logs integration is enabled by default in both examples (enable_cloudwatch_logs=true); the conditional is for lab flexibility.
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = var.trail_bucket_name
  s3_key_prefix                 = "cloudtrail/"
  kms_key_id                    = var.kms_key_arn
  sns_topic_name                = aws_sns_topic.trail.name
  include_global_service_events = var.include_global_service_events
  is_multi_region_trail         = var.is_multi_region_trail
  enable_logging                = true
  enable_log_file_validation    = var.enable_log_file_validation

  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.trail[0].arn : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs ? aws_iam_role.trail_to_cloudwatch[0].arn : null

  event_selector {
    include_management_events = true
    read_write_type           = "All"

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-trail"
  })

  depends_on = [aws_cloudwatch_log_group.trail]
}

# The CloudTrail S3 bucket policy is owned by the s3-logging module (which grants
# the CloudTrail service principal PutObject with bucket-owner-full-control) to
# avoid two aws_s3_bucket_policy resources conflicting on the same bucket.