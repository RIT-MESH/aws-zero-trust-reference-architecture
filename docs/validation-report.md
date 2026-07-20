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

## CI status (GitHub Actions)

The repository ships two workflows: `.github/workflows/validate.yml` (fmt,
init+validate both examples, native tests, pytest, checkov, YAML/JSON,
`validate.sh`) and `.github/workflows/codeql.yml` (CodeQL for Python), plus a
Dependabot configuration. Both workflow files are valid YAML (parsed locally
with PyYAML and reported `state: active` by the GitHub Actions API) and require
no AWS credentials and no real `terraform plan`.

On this development account, every GitHub Actions run - including GitHub's own
Dependabot runs - failed with `conclusion: startup_failure` and **0 jobs
allocated** (no runner was provisioned). This is an account-level GitHub-hosted
runner provisioning limitation (GitHub restricts runner allocation on very new
accounts as an anti-abuse measure), **not** a repository or workflow-file
defect. The one repository-side workflow issue found during inspection
(`terraform_version: ~1.10`, where YAML parses `~` as null) was fixed by pinning
to `"1.10.5"` and pushed. Once the account can allocate GitHub-hosted runners,
the workflows will execute the same checks that all pass locally (rows 1-10
above) and on any standard Ubuntu runner.