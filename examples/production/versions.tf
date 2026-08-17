terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.60"
    }
  }

  # Local backend by default so `terraform init`/`validate` work without credentials.
  # For real deployments, configure a remote backend (S3 + DynamoDB) outside this repo.
}
