# Zero Trust Principles -> AWS Controls

The architecture maps each Zero Trust tenet (NIST SP 800-207) to concrete AWS
controls implemented in this repository.

## 1. Verify explicitly

| Control | Where |
|---|---|
| IAM Identity Center as preferred workforce access (documented) | `docs/operations.md`, `modules/iam` |
| IAM roles, not long-lived users | all modules |
| MFA-gated break-glass role (no permanent credential) | `modules/iam` `aws_iam_role.break_glass` |
| Every request authenticated/authorized (SG references, IAM) | network, edge, ecs-app, rds |
| TLS everywhere (ALB TLS 1.2/1.3, KMS, S3 deny-insecure) | edge, kms, s3-logging |

## 2. Least-privilege access

| Control | Where |
|---|---|
| Workload task role deny-by-default | `modules/ecs-app` `aws_iam_role.task` |
| Task execution role scoped to ECR read + log writes + secret decrypt | `modules/ecs-app` |
| Permission boundary capping workload max permissions | `modules/iam` |
| DB SG accepts only the app SG on 5432 | `modules/rds` |
| ALB SG egress only to app SG; app SG ingress only from ALB SG | `modules/edge` |
| KMS key policies scoped to service principals | `modules/kms` |
| Example SCP (deny insecure S3, deny public RDS) | `modules/iam` output |

## 3. Assume breach

| Control | Where |
|---|---|
| Isolated data tier with no default route and denied egress | `modules/network`, `modules/rds` |
| Network segmentation by tier + SG references | `modules/network`, `edge`, `rds` |
| GuardDuty + CloudTrail Insights + Security Hub | `modules/security-services`, `modules/cloudtrail` |
| Continuous logging to tamper-evident S3 (versioned, access-logged) | `modules/s3-logging`, `modules/cloudtrail` |
| Incident-response containment levers documented | `docs/incident-response.md` |

## 4. No direct administrative access to workloads

| Control | Where |
|---|---|
| No inbound SSH (22) or RDP (3389) anywhere | enforced + tested (`tests/python`, native tests) |
| Session Manager for EC2 admin (SSM interface endpoints) | `modules/network` endpoints |
| ECS exec via SSM interface endpoints | `modules/network`, `modules/ecs-app` |
| No IAM users / access keys for workloads | all modules |

## 5. Network segmentation

| Control | Where |
|---|---|
| Public / private-app / isolated-data subnet tiers | `modules/network` |
| Separate route tables per tier | `modules/network` |
| Default SG restricted (no rules) | `modules/network` `aws_default_security_group` |
| SGs reference other SGs, not broad CIDRs | `modules/edge`, `modules/rds` |
| S3 gateway endpoint + interface endpoints | `modules/network` |

## 6. Encryption in transit and at rest

| Control | Where |
|---|---|
| ALB TLS 1.2/1.3 listener + HTTP->HTTPS redirect | `modules/edge` |
| S3 bucket policy denies insecure transport | `modules/s3-logging` |
| RDS `rds.force_ssl=1` (encryption in transit to DB) | `modules/rds` parameter group |
| RDS storage + Performance Insights encrypted with CMK | `modules/rds` |
| S3 SSE-KMS with bucket key | `modules/s3-logging` |
| Secrets Manager encrypted with CMK | `modules/rds` |
| CloudWatch log groups encrypted with CMK | `modules/cloudtrail`, `network`, `ecs-app`, `security-services` |
| KMS keys with annual rotation | `modules/kms` |

## 7. Continuous logging, detection, compliance, vulnerability mgmt

| Control | Where |
|---|---|
| CloudTrail (mgmt + S3 data events, Insights, SNS) | `modules/cloudtrail` |
| VPC Flow Logs (CloudWatch + S3 parquet) | `modules/network` |
| ALB access logs + WAF logs (auth header redacted) | `modules/edge`, `modules/s3-logging` |
| RDS postgresql logs exported | `modules/rds` |
| GuardDuty (incl. malware protection) | `modules/security-services` |
| Security Hub (CIS + AWS Foundational Best Practices) | `modules/security-services` |
| Inspector v2 (ECR + EC2) | `modules/security-services` |
| AWS Config recorder + conformance pack | `modules/security-services` |
| CloudWatch alarm on high-severity GuardDuty findings | `modules/security-services` |

## 8. Infrastructure as Code, automated validation, secure CI

| Control | Where |
|---|---|
| All infra is Terraform IaC (>= 1.6, AWS provider 5.x) | repo |
| `terraform fmt` + `validate` for both examples | CI, `scripts/validate.sh` |
| Native Terraform tests with mock provider (no AWS creds) | `modules/rds/tests`, `modules/network/tests` |
| Python security-invariant tests | `tests/python` |
| Checkov IaC scanning (0 failed) | CI, `scripts/validate.sh` |
| CodeQL for Python | `.github/workflows/codeql.yml` |
| Minimal workflow permissions, Dependabot | `.github/workflows`, `.github/dependabot.yml` |
| CI requires no AWS credentials and runs no `terraform plan` | CI workflows |
