# KMS module

Customer-managed KMS keys (CMKs) for logs, RDS, Secrets Manager, S3, and CloudTrail,
with annual key rotation enabled and least-privilege key policies.

## Security notes

- `enable_key_rotation` defaults to `true`.
- Key policies delegate administration to the placeholder account root and grant only the
  required service principals (logs delivery, CloudTrail, Secrets Manager) the Encrypt/Decrypt actions.
- `administrator_principals` defaults to a placeholder account root ARN. Replace with your
  real break-glass/admin principal ARNs; never commit personal IAM user ARNs.
