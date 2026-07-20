# Validation Report

This report records the local validation results for
`aws-zero-trust-reference-architecture`. **No AWS credentials were used, no
`terraform plan` was run against a real backend, and no `terraform apply` was
run.** Every check below was executed on the development host and re-runs in CI
via `.github/workflows/validate.yml`.

## Environment

| Tool | Version |
|---|---|
| OS | Windows 11 (10.0.26200) |
| Terraform | v1.15.8 |
| AWS provider | ~> 5.0 (resolved to 5.100.0) |
| Checkov | 3.3.8 |
| Python | 3.12.10 |
| pytest | 9.1.1 |
| Git | 2.55.0.windows.3 |
| gh | 2.96.0 |

## Results

| # | Check | Result |
|---|---|---|
| 1 | `terraform fmt -check -recursive` | PASS (no diffs) |
| 2 | `terraform init -backend=false` + `terraform validate` (examples/production) | PASS - "Success! The configuration is valid." |
| 3 | `terraform init -backend=false` + `terraform validate` (examples/lab) | PASS - "Success! The configuration is valid." |
| 4 | `terraform test` (modules/rds, mock provider) | PASS - 4 passed, 0 failed |
| 5 | `terraform test` (modules/network, mock provider) | PASS - 3 passed, 0 failed |
| 6 | `python -m pytest tests/python` | PASS - 14 passed |
| 7 | `checkov -d examples/production` | PASS - 266 passed, 0 failed, 32 skipped (justified) |
| 8 | `checkov -d examples/lab` | PASS - 267 passed, 0 failed, 31 skipped (justified) |
| 9 | YAML/JSON well-formedness (`scripts/_check_yaml_json.py`) | PASS |
| 10 | No forbidden/sensitive tracked files (git ls-files) | PASS |

## Native Terraform test cases (mock provider, no AWS)

`modules/rds/tests/rds.tftest.hcl`:
- RDS is not publicly accessible
- RDS storage is encrypted
- RDS has deletion protection and >=7-day backups
- DB security group has exactly one ingress (PostgreSQL from app SG)

`modules/network/tests/network.tftest.hcl`:
- Private app and isolated data subnets do not map public IPs
- VPC Flow Logs to CloudWatch are enabled
- S3 gateway VPC endpoint exists

## Python security-invariant tests

`tests/python/test_security_invariants.py` asserts (statically, no AWS):
- No SSH (22) or RDP (3389) ingress anywhere
- RDS not publicly accessible + module enforces `false` default
- ECS workloads have no public IP
- Private/data subnets do not map public IPs
- S3 public access block enabled (all four flags)
- RDS storage encrypted; S3 SSE-KMS; KMS key rotation enabled
- VPC Flow Logs present
- CloudTrail `enable_logging=true`
- Data tier has no default route
- Required tags present on key resources
- Outputs never expose secret values without `sensitive=true`

## Checkov suppressions

All `# checkov:skip=...` comments are inline on the relevant resource with a
written justification. See `docs/security-controls.md` for the full list and
rationale. Suppressions are narrowly scoped (break-glass role, permission
boundary ceiling, KMS key policy, S3 log-delivery ACL, lab cost levers, NAT EIPs,
RDS TLS graph-connection limitation, WAF association resolution, GuardDuty org
scope, and DB SG deny-all egress false positive).

## Skipped checks (host-specific)

- `bash scripts/validate.sh` end-to-end was not run successfully on the Windows
  development host because invoking the winget-installed `terraform.exe` through
  Git Bash triggers a Windows Installer "Class not registered"
  (`REGDB_E_CLASSNOTREG`) COM error in this environment. Each step the script
  performs was instead run directly via PowerShell (rows 1-10 above) and all
  passed. The script runs unchanged on the Ubuntu CI runner, where
  `terraform` is provided by `hashicorp/setup-terraform`.

## Confirmation

- No `terraform plan` or `terraform apply` was executed against any real backend.
- No live AWS resources were created, changed, or destroyed.
- No AWS credentials were required for any check above.

## Offline-validation mode (fake placeholder credentials)

The repository supports an explicit offline-validation mode for environments that
require the AWS Terraform provider to see credential values before it will
init/validate. This mode uses **fake placeholder** AWS environment variables only:

| Variable | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | `mock_access_key` |
| `AWS_SECRET_ACCESS_KEY` | `mock_secret_key` |
| `AWS_SESSION_TOKEN` | `mock_session_token` |
| `AWS_DEFAULT_REGION` | `ap-northeast-1` |
| `AWS_REGION` | `ap-northeast-1` |
| `AWS_EC2_METADATA_DISABLED` | `true` |

These are **not** real, valid, live, temporary, sandbox, or test-account AWS
credentials. They exist solely to satisfy the provider's credential parsing during
offline validation. They are exported into the shell session only (via
`scripts/offline-env.sh`) and are **never** written to `~/.aws/credentials`.

When `offline_validation=true` (set via `TF_VAR_offline_validation=true`), each
example's `provider "aws"` block sets `skip_credentials_validation`,
`skip_metadata_api_check`, and `skip_requesting_account_id`. This lets
`terraform init`/`validate`/`test` run with **no AWS API calls**. It does **not**
make `terraform plan`/`apply` work offline (data sources still require real AWS
access), and `terraform plan`/`apply` are never run with these dummy values.

Verified locally with the dummy env vars and `TF_VAR_offline_validation=true`:
`terraform init` + `terraform validate` pass for both examples; native Terraform
tests pass (rds 4/4, network 3/3); pytest passes (14/14). The default mode
(`offline_validation=false`, no env vars) also passes. No AWS API was contacted,
no `terraform plan`/`apply` was run, and no AWS resources were created, modified,
or destroyed.
## CI status (GitHub Actions)

The repository ships two workflows plus a Dependabot configuration:

- `.github/workflows/validate.yml` - `terraform fmt -check`, `terraform init + validate`
  for both examples, native Terraform tests (rds + network, mock provider), `pytest`,
  Checkov on both examples, YAML/JSON well-formedness, and `scripts/validate.sh`.
- `.github/workflows/codeql.yml` - CodeQL analysis for the Python test code.

Both workflows are valid YAML, require **no AWS credentials**, and run **no** real
`terraform plan`/`apply`. After the runner allocation settled (the very first runs on
the newly created repo briefly returned `startup_failure` before GitHub provisioned
runners), both workflows run **green** on `main`:

- `validate.yml` -> conclusion: **success**
- `codeql.yml` -> conclusion: **success**

A non-blocking deprecation annotation notes that several actions still target Node.js 20
(`actions/checkout@v4`, `actions/setup-python@v5`, `actions/upload-artifact@v4`,
`hashicorp/setup-terraform@v3`); these are warnings only and do not fail the run. Bump
those to their next major versions when convenient.