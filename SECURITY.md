# Security Policy

## Reporting a Vulnerability

This repository is a **reference architecture** and is not a running production
service. If you believe you have found a security weakness in the configuration,
IAM policies, or documentation, please open a GitHub issue with the label
`security` and describe the concern.

- Do **not** open issues that include real account IDs, domains, credentials, or
  customer data. Replace them with placeholders (`123456789012`,
  `example.com`, `203.0.113.0/24`).
- Do **not** report AWS account takeovers, active incidents, or vulnerabilities
  in AWS services here; those belong with AWS Support / AWS Abuse.
- There is no bug bounty program and no private reporting address is published
  to avoid exposing personal contact data.

## Response expectations

A maintainer will acknowledge reports within 7 days. Valid configuration
improvements will be addressed with a pull request; non-issues will be closed
with an explanation.

## Scope

In scope: Terraform configuration, IAM/SCP/permission-boundary policies, CI
workflows, and documentation security guidance.

Out of scope: the runtime security of any AWS account you deploy this into.
You are responsible for reviewing and adapting this reference to your
organization before use.
