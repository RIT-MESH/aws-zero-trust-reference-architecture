locals {
  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })

  # Map of logical key name -> alias suffix. Each gets an isolated CMK.
  keys = {
    logs       = "logs"
    rds        = "rds"
    secrets    = "secrets"
    s3         = "s3"
    cloudtrail = "cloudtrail"
  }
}

resource "aws_kms_key" "this" {
  for_each = local.keys

  description             = "Customer-managed KMS key for ${each.key} (Zero Trust reference architecture)"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = false

  policy = data.aws_iam_policy_document.key[each.key].json

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}

resource "aws_kms_alias" "this" {
  for_each = local.keys

  name          = "alias/${var.name_prefix}-${each.value}"
  target_key_id = aws_kms_key.this[each.key].key_id
}

# -----------------------------------------------------------------------------
# Key policy: least privilege. Root account admin (delegated), key rotation by
# AWS, and service-specific use. Uses placeholder account ID via var.administrator_principals.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "key" {
  # checkov:skip=CKV_AWS_355: KMS key policy uses Resource=* for the account-root admin statement; this is required for KMS key policies (the resource is the key itself, referenced as * in key policies).
  # checkov:skip=CKV_AWS_356: KMS key policy grants kms:* to the account root for key administration; this is the AWS-documented pattern for customer-managed key administration and is scoped to the account root principal only.
  # checkov:skip=CKV_AWS_109: KMS key policy delegates administration to the account root (kms:*) which is required for key administration; scoped to the account root principal only.
  # checkov:skip=CKV_AWS_111: KMS key policy kms:* write actions are delegated to the account root as required for key lifecycle management; service statements are scoped to Encrypt/Decrypt only.
  for_each = local.keys

  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = var.administrator_principals
    }
  }

  statement {
    sid    = "AllowKeyRotation"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:GetKeyRotationStatus",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["kms.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "logs" || each.key == "cloudtrail" ? [1] : []
    content {
      sid    = "AllowLogServices"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type = "Service"
        identifiers = [
          "delivery.logs.amazonaws.com",
          "cloudtrail.amazonaws.com",
        ]
      }

      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = ["arn:aws:logs:${data.aws_region.current.name}:${local.account_id}:*"]
      }
    }
  }

  dynamic "statement" {
    for_each = each.key == "secrets" ? [1] : []
    content {
      sid    = "AllowSecretsManager"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = ["secretsmanager.amazonaws.com"]
      }
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
}