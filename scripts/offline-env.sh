#!/usr/bin/env bash
# scripts/offline-env.sh
#
# Fake placeholder AWS environment variables for OFFLINE Terraform validation only.
#
# IMPORTANT:
#   - These are FAKE PLACEHOLDER VALUES. They are not real, valid, live, temporary,
#     sandbox, or test-account AWS credentials. They cannot authenticate to AWS and
#     must never be used against any real AWS account.
#   - Their only purpose is to satisfy the AWS Terraform provider's credential
#     parsing during offline `terraform init` / `terraform validate` / `terraform test`
#     (with a mock provider) so no AWS API calls are made.
#   - Do NOT run `terraform plan` or `terraform apply` with these values. Data sources
#     and resources still require real AWS API access, which these dummy values cannot
#     provide. No AWS resources are created, modified, or destroyed.
#   - These values are NOT written to ~/.aws/credentials. They are exported into the
#     current shell session only.
#
# Usage:
#   source scripts/offline-env.sh
#   export TF_VAR_offline_validation=true
#   cd examples/production && terraform init -backend=false && terraform validate
#
# When done, unset them (or start a new shell):
#   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
#         AWS_DEFAULT_REGION AWS_REGION AWS_EC2_METADATA_DISABLED TF_VAR_offline_validation

export AWS_ACCESS_KEY_ID="mock_access_key"
export AWS_SECRET_ACCESS_KEY="mock_secret_key"
export AWS_SESSION_TOKEN="mock_session_token"
export AWS_DEFAULT_REGION="ap-northeast-1"
export AWS_REGION="ap-northeast-1"
export AWS_EC2_METADATA_DISABLED="true"

echo "[offline-env] Fake placeholder AWS env vars exported for offline validation only."
echo "[offline-env] No AWS API calls will be made; do not run terraform plan/apply with these."
