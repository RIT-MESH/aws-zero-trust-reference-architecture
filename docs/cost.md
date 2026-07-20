# Cost

> This is a reference architecture, not a free tier. Running either example in
> a real AWS account incurs ongoing charges. See the cleanup instructions in the
> main README and run `terraform destroy` when finished.

## Production example (approximate, us-east-1, monthly)

| Resource | Notes | Rough order of magnitude |
|---|---|---|
| 2x NAT Gateway | One per AZ; ~$0.045/hr each + data processing | ~$65 + data |
| Application Load Balancer | LCU hours + processed bytes | ~$20-40 |
| WAFv2 | Per-rule + per-request | ~$10-30 |
| ECS Fargate | 3 tasks, 0.5 vCPU / 1 GB each | ~$30-45 |
| RDS PostgreSQL (Multi-AZ, m6g.large) | 2 AZ instances + storage | ~$130 |
| CloudTrail + CloudWatch Logs | Log ingestion + retention | ~$10-30 |
| GuardDuty / Security Hub / Inspector | Per-account + per-resource | ~$15-40 |
| KMS keys (5 CMKs) | Per-key-month + requests | ~$20 |
| S3 logging bucket | Storage + requests | ~$5 |

**Total ballpark: ~$300-450+/month**, dominated by Multi-AZ RDS and NAT Gateways.

## Lab example (cost levers applied)

| Lever | Setting | Effect |
|---|---|---|
| `single_nat_gateway` | `true` | One NAT GW instead of two (~$32/mo saved) |
| RDS `multi_az` | `false` | Single-AZ DB (~50% RDS cost saved) |
| RDS `deletion_protection` | `false` | Easier teardown (no cost) |
| `desired_count` | `1` | One Fargate task |
| ALB `enable_deletion_protection` | `false` | Easier teardown (no cost) |
| Log retention | shorter | Lower CloudWatch ingestion/retention cost |

**Lab ballpark: ~$120-180/month.** Still not free - NAT Gateway and RDS dominate.

## Tunable cost levers

- NAT Gateway count (`single_nat_gateway`).
- RDS instance class and Multi-AZ.
- Fargate task size and desired/min/max count.
- Log retention days (CloudWatch and S3 lifecycle).
- Enable/disable GuardDuty, Security Hub, Inspector, WAF managed rule groups.
- S3 lifecycle transitions (STANDARD_IA / GLACIER) and noncurrent version expiration.

## Clean up

Run `terraform destroy` from the example directory you applied from, then remove
the S3 logging bucket and any KMS keys (which have a deletion waiting period).
This repository does **not** apply anything automatically.
