# Security services module

Continuous logging, detection, compliance, and vulnerability management:
AWS Config, Amazon GuardDuty, AWS Security Hub (CIS + AWS Foundational Best
Practices), Amazon Inspector v2 (ECR + EC2), and CloudWatch finding alarms.

## Notes

- Inspector and GuardDuty are account-scoped; enabling them is idempotent and safe to apply.
- Security Hub subscribes to the CIS AWS Foundations Benchmark and the AWS Foundational
  Security Best Practices standard.
- A CloudWatch alarm forwards high-severity GuardDuty findings to the shared SNS topic.
- All resources are enabled by default but individually toggleable for lower-cost labs.
