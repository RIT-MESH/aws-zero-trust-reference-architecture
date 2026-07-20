# Edge module

Public ingress path: Route 53 / optional CloudFront -> AWS WAF -> internet-facing ALB -> private ECS targets.

## Resources

- Internet-facing Application Load Balancer in public subnets.
- Security group allowing 80/443 only from `allowed_ingress_cidrs`; egress references the
  application security group (SG reference, not a broad CIDR).
- HTTPS listener (TLS 1.2+ / TLS 1.3 policy) forwarding to the ECS target group, plus an
  HTTP -> HTTPS (301) redirect listener.
- AWS WAF v2 web ACL with the AWS Managed Common and Known Bad Inputs rule sets, an IP
  reputation + anonymous IP rule group (optional), and a per-IP rate-based block rule.
- ALB access logs and WAF logs to the centralized S3 logging bucket.

## Placeholders

- `certificate_arn` defaults to a placeholder ARN. Provide your own ACM certificate ARN.
- `allowed_ingress_cidrs` defaults to the documentation-only `203.0.113.0/24` (TEST-NET-3).

## Optional CloudFront / Route 53

CloudFront and Route 53 are intentionally not created by this module to keep `terraform validate`
from requiring a real hosted zone or domain. See `docs/architecture.md` for the recommended
front-end pattern and the placeholder inputs you would supply.
