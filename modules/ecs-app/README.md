# ECS application module

A private, Fargate-based application tier with least-privilege IAM roles, no public
IPs, ALB integration, CloudWatch logging, and CPU-based autoscaling.

## Zero Trust properties

- `assign_public_ip = false`; tasks run only in private application subnets.
- The app security group accepts traffic **only** from the ALB security group (SG reference).
- No inbound SSH/RDP exists anywhere in this module. Administration is via Systems Manager
  Session Manager against EC2 hosts in the same VPC (documented; not created here for Fargate).
- The workload task role is intentionally empty/deny-by-default; grant explicit permissions
  only as your application requires them.
- Container logs go to an encrypted, retention-managed CloudWatch log group.

## Placeholders

- `container_image` defaults to a placeholder ECR URI. Replace with your own image that
  serves a `/health` endpoint returning HTTP 200.
