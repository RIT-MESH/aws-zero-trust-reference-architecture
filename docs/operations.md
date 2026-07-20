# Operations

## Day-to-day administration

- **No direct admin access.** There is no inbound SSH (22) or RDP (3389) anywhere
  in the architecture. EC2 administration (when EC2 is used) is via Systems
  Manager Session Manager only; ECS Fargate tasks are administered via the ECS
  APIs and `aws ecs execute-command` (enabled through the SSM interface endpoints).
- **Workforce access** is via AWS IAM Identity Center (documented; not created by
  this repo). Use permission sets mapped to least-privilege IAM roles. Do not
  create long-lived IAM users.
- **Break-glass**: the `iam` module creates an MFA-gated break-glass role with
  short sessions. Use it only for emergencies and review every assumption via
  CloudTrail.

## Logging and observability

| Source | Destination | Retention |
|---|---|---|
| CloudTrail (management + S3 data events) | S3 (KMS) + CloudWatch Logs | S3 lifecycle / 365d CW |
| VPC Flow Logs | CloudWatch Logs + S3 (parquet) | 365d CW / S3 lifecycle |
| ALB access logs | S3 (KMS) | S3 lifecycle |
| WAF logs | S3 (KMS, Authorization header redacted) | S3 lifecycle |
| RDS postgresql logs | CloudWatch Logs | exported |
| ECS container logs | CloudWatch Logs (KMS) | 365d |
| GuardDuty findings | GuardDuty + CloudWatch alarm on High severity | SNS |

## Compliance posture

- AWS Config recorder is enabled with global resource types and a 6-hour delivery
  cadence; a conformance pack asserts required tags.
- Security Hub subscribes to the CIS AWS Foundations Benchmark and the AWS
  Foundational Security Best Practices standard.
- Inspector v2 scans ECR images and EC2 instances (when present).
- All findings can fan out via the shared SNS topic to your SOC/ITSM pipeline.

## Deployment workflow

1. Review and replace every placeholder (account ID, domain, certificate ARN,
   allowed CIDRs, container image).
2. Configure a remote Terraform backend (S3 + DynamoDB lock) outside this repo.
3. `terraform init` -> `terraform plan` -> human review -> `terraform apply`.
4. Never commit `terraform.tfstate`, `*.tfplan`, or lock files.

## Rotation

- KMS keys: automatic annual rotation enabled.
- RDS master credentials: managed by RDS in Secrets Manager; configure rotation
  via a Secrets Manager rotation Lambda in production (out of scope here).
- TLS certificates: provision via ACM and let ACM manage renewal.
