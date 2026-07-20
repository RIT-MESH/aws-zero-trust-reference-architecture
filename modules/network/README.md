# Network module

A two-AZ Zero Trust VPC foundation with segmented public, private application, and isolated data tiers.

## Resources

- VPC with DNS support/hostnames enabled, no public IPs on workloads.
- Public subnets (ALB + NAT Gateway only), private application subnets, isolated data subnets.
- One Internet Gateway and either one shared NAT Gateway (lab) or one per AZ (production).
- Separate route tables per tier; the data tier has no default route (assume-breach isolation).
- VPC Flow Logs to CloudWatch Logs (90 days) and optional S3 (long-term, parquet).
- Gateway VPC endpoint for S3 and interface endpoints for SSM, SSM Messages, EC2 Messages,
  CloudWatch Logs, Secrets Manager, KMS, and ECR (api/dkr).
- A security group for interface endpoints that only accepts HTTPS from the VPC CIDR.

## Inputs / Outputs

See `variables.tf` and `outputs.tf`. Apply `terraform-docs .` to regenerate this section if desired.

## Security notes

- No resource in the private application or isolated data tier receives a public IP.
- Security groups reference each other where the consuming module is responsible (see `ecs-app`, `edge`, `rds`).
- Network ACLs are intentionally left at AWS defaults and documented in `docs/security-controls.md`;
  security groups are the primary segmentation control.
