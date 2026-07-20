# Threat Model

Modelled with a lightweight STRIDE pass over the reference architecture. This is
a starting point; adapt it to your organization before production use.

## Assets

- Application workloads (ECS Fargate) and their task role credentials.
- Database (RDS PostgreSQL) and the data it holds.
- Secrets (RDS master credentials in Secrets Manager).
- Telemetry (CloudTrail, Flow Logs, WAF/ALB logs) used for detection and audit.
- KMS keys protecting the above.

## Trust boundaries

1. Internet -> WAF/ALB (untrusted to semi-trusted).
2. Public tier -> private app tier (ALB SG -> app SG reference only).
3. Private app tier -> isolated data tier (app SG -> DB SG on 5432 only).
4. VPC -> AWS services (interface endpoints, private DNS, no NAT for AWS APIs).
5. Account -> AWS control plane (IAM, CloudTrail, GuardDuty, Security Hub).

## STRIDE

| Threat | Where | Mitigation in this repo |
|---|---|---|
| Spoofing | ALB ingress | TLS 1.2/1.3, HTTP->HTTPS redirect, WAF, restricted `allowed_ingress_cidrs` |
| Spoofing | Workload identity | IAM roles + STS, no long-lived keys; task role deny-by-default |
| Tampering | Logs | S3 versioning, object lock-capable bucket, access logging on the log bucket, CloudTrail log file validation |
| Tampering | Config drift | AWS Config recorder + conformance pack; Security Hub standards |
| Repudiation | API actions | CloudTrail (mgmt + S3 data) with Insights, KMS-encrypted, SNS notifications |
| Information disclosure | DB | Private/isolated subnets, no public access (validated), DB SG only from app SG, `rds.force_ssl=1`, CMK encryption |
| Information disclosure | Secrets | Secrets Manager + CMK; secret values never output (tested) |
| Information disclosure | Logs | KMS-encrypted at rest; WAF redacts Authorization header |
| Denial of service | Public ingress | WAF rate-based rule + managed rule groups + IP reputation |
| Elevation of privilege | Workload | Least-privilege task role, permission boundary, example SCP |
| Elevation of privilege | Break-glass | MFA-gated AssumeRole, short sessions, CloudTrail-reviewed |
| Lateral movement | Tiers | Segmented subnets/route tables, no data-tier egress, default SG restricted |

## Assumed residual risks

- Single-account deployment; organization-level SCPs are provided as an example
  only and must be applied at the org/OU level by you.
- IAM Identity Center is documented, not provisioned (requires an organization).
- Secrets Manager rotation Lambda for RDS is out of scope; configure it in prod.
- CloudFront and Route 53 are documented/optional to keep `terraform validate`
  free of a real hosted zone.
- Checkov suppressions are documented inline with justifications; review them
  during your own acceptance.
