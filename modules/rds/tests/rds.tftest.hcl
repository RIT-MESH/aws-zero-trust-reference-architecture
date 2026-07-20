# Native Terraform test for the RDS module. Uses a mock provider so it runs
# without AWS credentials and without applying any resources.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
}

variables {
  name_prefix           = "zt-test"
  vpc_id                = "vpc-fake"
  subnet_ids            = ["subnet-fake-1", "subnet-fake-2"]
  app_security_group_id = "sg-fake-app"
  kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/fake-rds"
  secrets_kms_key_arn   = "arn:aws:kms:us-east-1:123456789012:key/fake-secrets"
}

run "rds_is_not_publicly_accessible" {
  command = plan

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "RDS must not be publicly accessible"
  }
}

run "rds_storage_is_encrypted" {
  command = plan

  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "RDS storage must be encrypted with a customer-managed KMS key"
  }
}

run "rds_has_deletion_protection_and_backups" {
  command = plan

  assert {
    condition     = aws_db_instance.this.deletion_protection == true
    error_message = "RDS deletion protection must be enabled (production default)"
  }

  assert {
    condition     = aws_db_instance.this.backup_retention_period >= 7
    error_message = "RDS backup retention must be at least 7 days"
  }
}

run "db_security_group_only_allows_app_sg" {
  command = plan

  assert {
    condition     = length(aws_security_group.db.ingress) == 1
    error_message = "DB SG must have exactly one ingress rule (from the app SG)"
  }

  assert {
    condition     = alltrue([for r in aws_security_group.db.ingress : r.from_port == 5432])
    error_message = "DB SG ingress must be PostgreSQL (5432)"
  }
}
