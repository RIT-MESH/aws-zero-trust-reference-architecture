# AWS authentication

This project uses the **standard AWS credential provider chain**. No credentials
are stored in the repository, and no credentials are placed in the Terraform
provider block. Authenticate through one of the methods below before running
`terraform init`, `terraform plan`, or `terraform apply`.

## Supported methods

1. **AWS IAM Identity Center (SSO)** - recommended for human operators.
2. **AWS CLI named profile** - `export AWS_PROFILE=<name>`.
3. **Environment variables** - `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (or
   `AWS_SESSION_TOKEN` for temporary credentials) set in your shell session, never
   committed.
4. **IAM role attached to an EC2 instance or self-hosted runner** - the EC2
   instance profile or runner role provides credentials automatically.
5. **GitHub Actions OIDC** - a GitHub Actions workflow assumes an IAM role via
   OIDC; see [github-oidc.md](github-oidc.md).

## Recommended local setup (IAM Identity Center)

```bash
aws configure sso
aws sso login --profile zero-trust-prod
export AWS_PROFILE=zero-trust-prod
export AWS_REGION=ap-northeast-1
```

Verify the authenticated identity before planning:

```bash
aws sts get-caller-identity
```

## Provider configuration

The examples use a standard provider configuration. There are no `access_key`,
`secret_key`, or `token` arguments:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

## What not to do

- Do not store AWS access keys in Terraform files, `.tfvars` files, shell scripts,
  GitHub repository variables, or committed configuration.
- Do not edit the provider block to insert credentials.
- Do not commit `~/.aws/credentials` or any private key material.

If no alternative to a long-lived key exists, scope it to a single least-privilege
IAM user, store it only in your shell session or a secrets manager, and rotate it
frequently.
