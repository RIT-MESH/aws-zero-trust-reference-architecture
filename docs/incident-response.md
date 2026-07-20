# Incident Response

This reference architecture follows an **assume-breach** posture: detections and
logs are pre-wired so that a compromise is observable and containable.

## Detection signals

- **GuardDuty**: unauthorized API use, replayed credentials, anomalous S3/EC2
  behavior, malware-protection EBS scans. A CloudWatch alarm fires on High-severity
  findings and publishes to the shared SNS topic.
- **CloudTrail + Insights**: management events, S3 data events, and API call/error
  rate anomalies.
- **Security Hub**: aggregated findings from CIS and AWS Foundational Best
  Practices standards.
- **VPC Flow Logs**: east-west and north-south network telemetry (CloudWatch +
  S3/parquet for querying).
- **Inspector**: vulnerable packages in ECR images and EC2 instances.
- **AWS Config**: configuration drift on tracked resource types.

## Containment levers

| Scenario | Lever |
|---|---|
| Compromised workload | Quarantine the ECS task SG / move tasks to an isolated SG; rotate the task role via redeploy |
| Compromised DB credentials | Force rotation via Secrets Manager; the DB SG only accepts the app SG |
| Abusive source IP | Tighten `allowed_ingress_cidrs`; rely on WAF IP reputation + rate-based rule |
| Lateral movement | Data tier has no default route and denies egress; private tiers are segmented by SGs |
| Credential exposure | Revoke via IAM; CloudTrail records who assumed what and when |

## Eradication & recovery

1. Isolate the affected resource (security group moves, task replacement).
2. Rotate secrets (Secrets Manager) and IAM temporary credentials.
3. Patch the vulnerable image and redeploy the ECS service (circuit breaker + rollback enabled).
4. Restore RDS from an automated backup if data integrity is in question.
5. Review CloudTrail/Flow Logs for blast radius.

## Post-incident

- Capture findings into Security Hub and your ticketing system.
- Update the threat model (`docs/threat-model.md`) and add regression checks to
  `tests/python/test_security_invariants.py` and the native Terraform tests.
- Review whether a checkov suppression or a config default should change.

## Who to involve

This repo does not embed personal contact data. Define your on-call, SOC, and
AWS Support escalation paths in your own runbook and wire the shared SNS topic to
them.
