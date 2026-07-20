# GitHub Actions OIDC (deployment authentication)

The optional deployment workflow
`.github/workflows/terraform-deploy.example.yml` authenticates to AWS using
**GitHub Actions OIDC** - no long-lived AWS access keys are stored in GitHub.

## How it works

1. GitHub Actions requests an OIDC token (`permissions: id-token: write`).
2. `aws-actions/configure-aws-credentials@v4` exchanges the OIDC token for
   short-lived AWS credentials by assuming an IAM role.
3. The IAM role ARN is supplied through repository/environment configuration
   (e.g. a repository variable or environment secret named `AWS_DEPLOY_ROLE_ARN`),
   never committed to the source.

## Required IAM role trust policy

Create an IAM role with a trust policy that allows the GitHub OIDC provider to
assume it only for this repository (and optionally only for the `main` branch or
a protected environment). Replace the placeholders:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:RIT-MESH/aws-zero-trust-reference-architecture:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

For environment-scoped access (recommended for `apply`), tighten the `sub`
condition to `repo:<org>/<repo>:environment:<name>` and attach the role to a
protected GitHub Environment.

## Required IAM permissions

Attach a least-privilege managed/custom policy to the role that permits
provisioning the resources in this repository (VPC, ECS, RDS, KMS, S3, IAM,
security services, etc.). Do **not** attach `AdministratorAccess` for production.

## Enabling the workflow

The workflow file is named `terraform-deploy.example.yml` so it does **not** run
automatically. To enable it, rename it to `terraform-deploy.yml` and configure:

- Repository variable or environment secret `AWS_DEPLOY_ROLE_ARN` (the OIDC role ARN).
- Repository variable `AWS_REGION` (e.g. `ap-northeast-1`).
- A protected GitHub Environment named `production` with required reviewers for
  the `apply` job.

Until you do this, no deployment runs from CI.
