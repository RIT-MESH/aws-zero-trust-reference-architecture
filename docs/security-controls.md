# Security Controls

A consolidated, auditable list of the security controls implemented, where they
live, and how they are verified.

## Network

| Control | Implementation | Verification |
|---|---|---|
| No public IPs on app/data workloads | subnets `map_public_ip_on_launch=false`; ECS `assign_public_ip=false` | native test + python test |
| No SSH/RDP ingress | no ingress rules on 22/3389 anywhere | python test |
| Tier segmentation | public/app/data subnets + separate route tables | python test (data tier no default route) |
| Data tier isolation | data route table has no default route; DB SG egress denied | native test + python test + checkov (suppressed, justified) |
| Default SG restricted | `aws_default_security_group` with no rules | checkov CKV2_AWS_12 |
| VPC Flow Logs | CloudWatch + S3 (parquet) | python test + checkov |
| Private AWS service access | S3 gateway + SSM/Logs/Secrets/KMS/ECR interface endpoints | native test |
| SG references not CIDRs | ALB->app and app->DB use SG references | python test (DB SG single ingress from app SG) |

## Edge

| Control | Implementation | Verification |
|---|---|---|
| TLS termination | ALB HTTPS listener, `ELBSecurityPolicy-TLS13-1-2-2021-06` | checkov |
| HTTP->HTTPS redirect | HTTP listener 301 | checkov |
| WAF managed rules | Common, Known Bad Inputs, IP reputation, Anonymous IP, Linux (Log4j) | checkov |
| Rate-based blocking | per-IP rate-based rule | checkov |
| WAF logging | S3 with Authorization header redaction | checkov (suppressed, justified) |
| ALB access logs | S3 (KMS) | checkov |
| ALB deletion protection | configurable, enabled in production | checkov (suppressed, justified - lab) |
| Drop invalid headers | `drop_invalid_header_fields=true` | checkov |

## Compute

| Control | Implementation | Verification |
|---|---|---|
| No public IP | Fargate `assign_public_ip=false` | native? python test |
| Private subnets only | service subnets = private app subnets | - |
| Least-privilege task role | deny-by-default policy | - |
| Scoped execution role | ECR read + log writes + secret decrypt only | checkov |
| Container log encryption | CloudWatch KMS | checkov |
| Fargate latest platform | `platform_version="LATEST"` | checkov |
| Autoscaling | target tracking on CPU | - |
| Security headers | documented dockerLabels + app layer guidance | docs |

## Data

| Control | Implementation | Verification |
|---|---|---|
| Not publicly accessible | validation forces `publicly_accessible=false` | native test + python test + checkov |
| CMK encryption at rest | `storage_encrypted` + `kms_key_id` | checkov |
| TLS to DB | `rds.force_ssl=1` parameter | checkov (suppressed, justified - graph conn) |
| Secrets Manager credentials | `manage_master_user_password` + CMK | - |
| No secret value in outputs | outputs expose ARN only, secret output sensitive | python test |
| Multi-AZ (prod) | configurable, enabled in prod | checkov (suppressed, justified - lab) |
| Deletion protection (prod) | configurable, enabled in prod | checkov (suppressed, justified - lab) |
| Backups | `backup_retention_period` 7-35d | native test |
| Enhanced monitoring | `monitoring_interval=30` + role | checkov |
| Query logging | parameter group `log_statement=all`, etc. | checkov |
| DB SG only from app SG | single ingress from app SG on 5432 | native test |

## Identity

| Control | Implementation | Verification |
|---|---|---|
| Roles not users | all IAM is roles | - |
| Break-glass MFA | AssumeRole requires MFA + short sessions | checkov (suppressed, justified) |
| Permission boundary | managed policy capping workload max perms | checkov (suppressed, justified) |
| Example SCP | output JSON for org application | - |
| Identity Center | documented | docs |

## Logging / detection / compliance

| Control | Implementation | Verification |
|---|---|---|
| CloudTrail | multi-region, KMS, log file validation, Insights, SNS | checkov |
| Config | recorder + delivery + conformance pack | - |
| GuardDuty | detector + S3 logs + malware protection | checkov (suppressed, justified) |
| Security Hub | CIS + AWS Foundational standards | - |
| Inspector v2 | ECR + EC2 | - |
| Log retention | 365d for audit logs; S3 lifecycle | checkov |
| Finding alarm | CloudWatch alarm on High GuardDuty findings | - |

## CI / supply chain

| Control | Implementation |
|---|---|
| Minimal workflow permissions | `permissions: contents: read` (+ security-events for CodeQL) |
| No AWS creds in CI | workflows never configure AWS provider credentials |
| No real plan/apply in CI | only init + validate + test + static scans |
| Dependabot | github-actions, terraform, pip ecosystems |
| CodeQL | python analysis |
| IaC scanning | checkov (0 failed) |
| Secret-free repo | `scripts/validate.sh` + .gitignore + tested |

## Checkov suppressions and justifications

All `# checkov:skip=...` comments are inline on the relevant resource with a
written justification. Summary of categories:

- **Permission boundary / KMS key policy / flow-log role**: a boundary or key
  policy must include an Allow ceiling; Deny statements enforce constraints, or
  `Resource="*"` is required because the target ARN is not known at creation.
- **Break-glass role**: AdministratorAccess is intentional and MFA-gated.
- **S3 logging bucket**: ACL `log-delivery-write` is AWS-required for S3 server
  access log delivery; cross-region replication and event notifications are
  environment-specific and out of scope.
- **Lab cost levers**: ALB/RDS deletion protection and RDS Multi-AZ are
  intentionally off in the lab example; both are enabled in production.
- **NAT EIPs**: attached to NAT Gateways, not EC2 (the check only considers EC2).
- **RDS TLS**: `rds.force_ssl=1` is set in the parameter group; checkov 3.x does
  not detect the db_instance->parameter_group graph connection.
- **WAF logging / Log4j rule**: implemented; checkov cannot statically resolve the
  ALB->WACL association.
- **GuardDuty org**: single-account reference; regional detector enabled.
- **DB SG egress**: empty `cidr_blocks` denies all egress (false positive on `-1`).

Review every suppression during your own acceptance process.
