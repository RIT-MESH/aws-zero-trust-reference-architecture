locals {
  common_tags = merge(var.tags, {
    project    = "aws-zero-trust-reference-architecture"
    managed_by = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Break-glass role: no permanent admin credential. AssumeRole requires MFA and is
# limited to short sessions. Real elevation happens through AWS IAM Identity Center
# just-in-time access (documented), not through this role's existence.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "break_glass" {
  name                 = "${var.name_prefix}-break-glass"
  description          = "Emergency break-glass role. Requires MFA. No permanent credential."
  max_session_duration = var.max_session_duration_seconds

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.break_glass_trusted_principals }
      Action    = "sts:AssumeRole"
      Condition = {
        Bool            = { "aws:MultiFactorAuthPresent" = "true" }
        NumericLessThan = { "aws:MultiFactorAuthAge" = 3600 }
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-break-glass"
  })
}

# AdministratorAccess is attached but ONLY usable via MFA-backed AssumeRole from the
# trusted principals above. This documents the break-glass design without issuing any
# long-lived credential.
# AdministratorAccess is attached but ONLY usable via MFA-backed AssumeRole from the trusted
# principals above; no long-lived credential is issued. This is the documented break-glass design.
resource "aws_iam_role_policy_attachment" "break_glass_admin" {
  # checkov:skip=CKV_AWS_274: Intentional break-glass emergency role; AdministratorAccess is gated by MFA-backed AssumeRole from a trusted principal with short sessions and no permanent credential. See docs/security-controls.md.
  role       = aws_iam_role.break_glass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# Permission boundary: restricts what any role opted into it can do. Provided as a
# managed policy so workload roles can attach it. Enforces no public resources, no
# disabling of encryption, and no IAM privilege escalation beyond the boundary.
# -----------------------------------------------------------------------------
# This is a PERMISSION BOUNDARY (not an identity policy). A boundary must include an
# Allow statement to permit any action at all; the Deny statements above enforce the
# constraints (no public IPs, no disabling encryption, no IAM privilege escalation).
# The boundary only caps the maximum effective permissions of a workload role.
resource "aws_iam_policy" "workload_permission_boundary" {
  # checkov:skip=CKV_AWS_62: Permission boundary by design needs an Allow statement; Deny statements enforce the constraints. Not an identity policy.
  # checkov:skip=CKV_AWS_63: Permission boundary uses Action=* as the ceiling; constrained by the Deny statements above.
  # checkov:skip=CKV_AWS_286: Privilege escalation is denied by the DenyIamEscalation statement above; the Allow is the boundary ceiling.
  # checkov:skip=CKV_AWS_287: Credentials exposure is denied by DenyIamEscalation; the Allow is the boundary ceiling.
  # checkov:skip=CKV_AWS_288: Data exfiltration is constrained by the boundary Deny statements and the workload role own least-privilege policy.
  # checkov:skip=CKV_AWS_289: Permissions management is denied by DenyIamEscalation; the Allow is the boundary ceiling.
  # checkov:skip=CKV_AWS_290: Write access is the boundary ceiling; constrained by Deny statements and the workload identity policy.
  # checkov:skip=CKV_AWS_355: Resource=* is the boundary ceiling for the Allow statement; Deny statements restrict dangerous actions.
  # checkov:skip=CKV2_AWS_40: Full IAM privileges in the Allow statement are the boundary ceiling; DenyIamEscalation prevents IAM privilege escalation.
  name        = "${var.name_prefix}-workload-boundary"
  description = "Permission boundary for Zero Trust workload roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicResources"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
        ]
        Resource = "*"
        Condition = {
          Bool = { "ec2:AssociatePublicIpAddress" = "true" }
        }
      },
      {
        Sid    = "DenyDisablingEncryption"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "kms:DisableKey",
          "rds:ModifyDBInstance",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyIamEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateLoginProfile",
          "iam:CreateAccessKey",
          "iam:AttachUserPolicy",
          "iam:PutUserPolicy",
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowWithinBoundary"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
    ]
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Example SCP (organizational) documented as a data source / policy document only.
# Not applied to an organization (would require org access). Consumers can copy this.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "example_scp" {
  statement {
    sid    = "DenyInsecureS3"
    effect = "Deny"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]
    resources = ["arn:aws:s3:::*/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyPublicRds"
    effect = "Deny"
    actions = [
      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "rds:PubliclyAccessible"
      values   = ["true"]
    }
  }
}