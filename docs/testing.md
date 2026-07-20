# Testing

Automated tests and validation run **without contacting AWS** and without AWS
credentials. They verify the configuration statically and with mocked provider
behavior.

## What runs

- `terraform fmt -check -recursive` - formatting.
- `terraform init -backend=false` + `terraform validate` for both examples -
  schema validation, no AWS API calls.
- `terraform test` - native Terraform tests in `modules/rds/tests` and
  `modules/network/tests` using a `mock_provider "aws"` so no AWS credentials or
  API calls are required.
- `python -m pytest tests/python` - static security-invariant tests (no SSH/RDP,
  RDS not public, no public IPs on workloads, S3 public block, encryption, flow
  logs, CloudTrail, data-tier isolation, tags, no secret outputs, no AWS key
  patterns committed).
- `checkov` - IaC security scanning (Terraform).
- `tflint` - Terraform linting.
- `yamllint` / `actionlint` / `shellcheck` - lint workflow and shell files.
- `gitleaks` - secret scanning to confirm no credentials are committed.

## Running locally

```bash
terraform fmt -check -recursive
( cd examples/production && terraform init -backend=false && terraform validate )
( cd examples/lab       && terraform init -backend=false && terraform validate )
( cd modules/rds    && terraform init -backend=false && terraform test )
( cd modules/network && terraform init -backend=false && terraform test )
python -m pytest tests/python -q
checkov -d examples/production --framework terraform --quiet
checkov -d examples/lab       --framework terraform --quiet
bash scripts/validate.sh
```

CI runs the same set in `.github/workflows/validate.yml`. Results are recorded in
[validation-report.md](validation-report.md).

## Notes

- Native Terraform tests use `mock_provider`, which is a Terraform testing feature
  and is separate from deployment. It does not require or use AWS credentials.
- No `terraform plan` or `terraform apply` is run by the test suite.
