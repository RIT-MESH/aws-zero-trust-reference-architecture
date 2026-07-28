# Beginner’s Guide: AWS Zero Trust Reference Architecture

Repository: `RIT-MESH/aws-zero-trust-reference-architecture`

## 1. What this project builds

This repository contains a production-oriented Zero Trust reference architecture on AWS using Terraform.

The main traffic flow is:

```text
Internet
   ↓
AWS WAF
   ↓
Application Load Balancer
   ↓
ECS Fargate application in private subnets
   ↓
RDS PostgreSQL in isolated subnets
```

The architecture also includes:

- CloudTrail
- VPC Flow Logs
- AWS Config
- GuardDuty
- Security Hub
- Inspector
- CloudWatch
- Encrypted S3 log storage
- Customer-managed KMS keys
- IAM permission boundaries
- MFA-protected break-glass access

The application and database do not receive public IP addresses. Security groups only allow required traffic, such as ALB to ECS and ECS to PostgreSQL on port 5432.

---

## 2. Repository structure

```text
modules/
├── network
├── kms
├── s3-logging
├── cloudtrail
├── edge
├── ecs-app
├── rds
├── security-services
└── iam

examples/
├── lab
└── production

docs/
tests/
scripts/
.github/workflows/
```

Each Terraform module has one responsibility.

The production configuration connects the modules in this order:

1. KMS encryption keys
2. Centralized S3 logging
3. CloudTrail
4. VPC and networking
5. WAF and Application Load Balancer
6. ECS Fargate application
7. RDS PostgreSQL
8. Security monitoring services
9. IAM security controls

---

## 3. Cost warning

This architecture is not free.

Approximate monthly costs from the project documentation:

- Production: around USD 300–450 or more
- Lab: around USD 120–180

The largest costs normally come from:

- NAT Gateways
- RDS
- ECS tasks
- Security services
- Log storage
- VPC endpoints

For learning, use `examples/lab` first.

Important:

- Never store AWS access keys in Terraform files.
- Never commit `terraform.tfvars`.
- Always run `terraform plan` before `terraform apply`.
- Run `terraform destroy` after testing.
- Some S3 buckets and KMS keys may need manual cleanup.

---

## 4. Install the required tools

You need:

1. AWS account
2. AWS CLI
3. Terraform
4. Git
5. Visual Studio Code or another editor
6. Docker, only if you want to build your own container image

Check the installed versions in PowerShell:

```powershell
aws --version
terraform version
git --version
docker --version
```

The repository requires Terraform 1.6 or newer and AWS Provider 5.x.

---

## 5. Clone the repository

Open PowerShell:

```powershell
cd $HOME
mkdir aws-projects
cd aws-projects

git clone https://github.com/RIT-MESH/aws-zero-trust-reference-architecture.git

cd aws-zero-trust-reference-architecture
```

Check the files:

```powershell
Get-ChildItem
```

You should see:

```text
docs
examples
modules
scripts
tests
```

---

## 6. Understand the Terraform files

### `main.tf`

Contains the modules and resources Terraform should create.

Example:

```hcl
module "network" {
  source = "../../modules/network"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}
```

### `variables.tf`

Defines the input values.

```hcl
variable "aws_region" {
  type = string
}
```

### `terraform.tfvars`

Provides actual values.

```hcl
aws_region = "ap-northeast-1"
```

### `outputs.tf`

Displays useful deployment information, such as:

- ALB DNS name
- VPC ID
- ECS cluster name
- RDS endpoint
- Break-glass role ARN

### `versions.tf`

Defines compatible Terraform and provider versions.

---

## 7. Configure AWS authentication

This project uses the normal AWS credential provider chain.

AWS IAM Identity Center or AWS SSO is recommended.

Run:

```powershell
aws configure sso
```

Use a profile name such as:

```text
zero-trust-lab
```

Log in:

```powershell
aws sso login --profile zero-trust-lab
```

Set the profile for the current PowerShell session:

```powershell
$env:AWS_PROFILE = "zero-trust-lab"
$env:AWS_REGION = "ap-northeast-1"
```

Verify your identity:

```powershell
aws sts get-caller-identity
```

Expected output:

```json
{
  "UserId": "...",
  "Account": "123456789012",
  "Arn": "arn:aws:..."
}
```

Do not continue until this command works.

---

## 8. Choose lab or production

The repository provides:

```text
examples/lab
examples/production
```

Use the lab environment first:

```powershell
cd examples\lab
```

The production configuration includes stronger settings, such as:

- NAT Gateway per Availability Zone
- Three ECS tasks
- Multi-AZ RDS
- RDS deletion protection
- Longer log retention

---

## 9. Create the variables file

Copy the example file:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Open it:

```powershell
notepad terraform.tfvars
```

A typical Tokyo configuration starts like this:

```hcl
aws_region         = "ap-northeast-1"
environment        = "lab"
name_prefix        = "zt-lab"
vpc_cidr           = "10.20.0.0/16"

availability_zones = [
  "ap-northeast-1a",
  "ap-northeast-1c"
]
```

Check the Availability Zones available to your AWS account:

```powershell
aws ec2 describe-availability-zones `
  --region ap-northeast-1 `
  --query "AvailabilityZones[?State=='available'].ZoneName" `
  --output table
```

The complete variables file will also require values such as:

```hcl
allowed_ingress_cidrs = ["YOUR.PUBLIC.IP.ADDRESS/32"]

certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/..."

container_image = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/zero-trust-app:v1"

db_instance_class = "db.t4g.micro"
```

Never place passwords or access keys in this file.

---

## 10. Understand the network design

The VPC is divided into three tiers.

### Public subnets

Contain:

- Application Load Balancer
- NAT Gateway

They have a route to the Internet Gateway.

### Private application subnets

Contain:

- ECS Fargate tasks
- VPC interface endpoints

The ECS tasks do not have public IP addresses.

They can use NAT Gateway for outbound internet access when required.

### Isolated database subnets

Contain:

- RDS PostgreSQL

These subnets have no default internet route.

Conceptually:

```text
VPC 10.20.0.0/16

Availability Zone A
├── Public subnet
├── Private application subnet
└── Isolated database subnet

Availability Zone B
├── Public subnet
├── Private application subnet
└── Isolated database subnet
```

---

## 11. Create a simple application container

The ECS service expects a container that:

1. Listens on port `8080`
2. Responds to `GET /health`
3. Returns HTTP status `200`

Example `app.py`:

```python
from flask import Flask

app = Flask(__name__)


@app.get("/")
def home():
    return {"message": "Zero Trust application is running"}


@app.get("/health")
def health():
    return {"status": "healthy"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

Example `requirements.txt`:

```text
Flask==3.1.1
gunicorn==23.0.0
```

Example `Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
```

---

## 12. Create an ECR repository

Set variables:

```powershell
$Region = "ap-northeast-1"
$RepositoryName = "zero-trust-app"
```

Create the repository:

```powershell
aws ecr create-repository `
  --repository-name $RepositoryName `
  --region $Region `
  --image-scanning-configuration scanOnPush=true
```

Get your account ID:

```powershell
$AccountId = aws sts get-caller-identity `
  --query Account `
  --output text
```

Build the image URI:

```powershell
$ImageUri = "$AccountId.dkr.ecr.$Region.amazonaws.com/${RepositoryName}:v1"

$ImageUri
```

Log in to ECR:

```powershell
aws ecr get-login-password --region $Region |
docker login `
  --username AWS `
  --password-stdin "$AccountId.dkr.ecr.$Region.amazonaws.com"
```

Build the image:

```powershell
docker build -t "${RepositoryName}:v1" .
```

Tag it:

```powershell
docker tag "${RepositoryName}:v1" $ImageUri
```

Push it:

```powershell
docker push $ImageUri
```

Add the image URI to `terraform.tfvars`:

```hcl
container_image = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/zero-trust-app:v1"
```

---

## 13. Create an ACM certificate

The Application Load Balancer uses HTTPS.

The ACM certificate must exist in the same AWS region as the ALB.

Example domain:

```text
app.example.com
```

Request a certificate:

```powershell
aws acm request-certificate `
  --domain-name app.example.com `
  --validation-method DNS `
  --region ap-northeast-1
```

The result contains a certificate ARN:

```json
{
  "CertificateArn": "arn:aws:acm:ap-northeast-1:123456789012:certificate/..."
}
```

Complete DNS validation.

Check the status:

```powershell
aws acm describe-certificate `
  --certificate-arn "YOUR_CERTIFICATE_ARN" `
  --region ap-northeast-1 `
  --query "Certificate.Status"
```

Continue only when it says:

```text
ISSUED
```

Add it to `terraform.tfvars`:

```hcl
certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/..."
```

---

## 14. Restrict incoming traffic

The variable below controls which public IPs can access the ALB:

```hcl
allowed_ingress_cidrs
```

For personal testing, use your public IP with `/32`:

```hcl
allowed_ingress_cidrs = [
  "YOUR.PUBLIC.IP.ADDRESS/32"
]
```

Do not use this unless you intentionally want the ALB open to everyone:

```hcl
allowed_ingress_cidrs = ["0.0.0.0/0"]
```

---

## 15. Initialize Terraform

From the lab directory:

```powershell
terraform init
```

Terraform will:

1. Read the configuration.
2. Download the AWS provider.
3. Load referenced modules.
4. Create the `.terraform` directory.
5. Create or update `.terraform.lock.hcl`.

For a first test, local Terraform state is acceptable.

---

## 16. Format and validate

Run:

```powershell
terraform fmt -check
terraform validate
```

To automatically fix formatting:

```powershell
terraform fmt -recursive
```

`terraform validate` checks:

- Syntax
- Module references
- Variable types
- Resource structure

---

## 17. Create and review a Terraform plan

Run:

```powershell
terraform plan -out=tfplan
```

Inspect the plan:

```powershell
terraform show tfplan
```

Terraform symbols:

```text
+ create
~ update
- destroy
-/+ replace
```

Review carefully:

- Public subnet routes
- Security group ingress
- IAM policies
- ECS task count
- RDS settings
- KMS keys
- S3 policies
- Deletion protection
- Public exposure

Do not apply until the plan matches your intent.

---

## 18. Apply the infrastructure

After reviewing the plan:

```powershell
terraform apply tfplan
```

Terraform will create the infrastructure according to dependencies.

Approximate order:

```text
KMS keys
   ↓
Logging S3 buckets
   ↓
VPC and networking
   ↓
CloudTrail and monitoring
   ↓
Security groups
   ↓
WAF and ALB
   ↓
ECS cluster and service
   ↓
RDS database
   ↓
Security services and IAM controls
```

Terraform automatically determines the order from references between modules.

---

## 19. Major components explained

### 19.1 KMS encryption

Separate customer-managed KMS keys are used for:

- Logs
- RDS
- Secrets
- S3
- CloudTrail

Benefits:

- Better access separation
- Easier auditing
- Reduced impact from policy mistakes
- Independent key lifecycle

### 19.2 Centralized logging bucket

The S3 logging bucket stores logs from:

- CloudTrail
- VPC Flow Logs
- ALB
- WAF
- AWS Config

Security features include:

- Public access block
- Versioning
- KMS encryption
- Access logging
- HTTPS-only access

### 19.3 CloudTrail

CloudTrail records AWS API activity.

Examples:

```text
CreateSecurityGroup
ModifyDBInstance
PutBucketPolicy
AssumeRole
CreateAccessKey
StopLogging
```

The project enables:

- Multi-region logging
- Log file validation
- CloudWatch Logs
- CloudTrail Insights
- Long retention

### 19.4 VPC and segmentation

The network module creates:

- VPC
- Internet Gateway
- Public subnets
- Private application subnets
- Isolated database subnets
- Route tables
- NAT Gateways
- VPC Flow Logs
- VPC endpoints
- Restricted default security group

### 19.5 VPC endpoints

Private ECS tasks use endpoints for AWS services such as:

- SSM
- SSM Messages
- EC2 Messages
- CloudWatch Logs
- Secrets Manager
- KMS
- ECR
- S3

This reduces the need to send AWS service traffic through the public internet.

### 19.6 WAF and Application Load Balancer

The edge module creates:

- Internet-facing ALB
- HTTPS listener
- HTTP-to-HTTPS redirect
- Target group
- ALB security group
- Application security group
- WAF Web ACL
- WAF managed rules
- Rate limiting

The ALB forwards traffic to ECS on port `8080`.

The health check path is:

```text
/health
```

### 19.7 ECS Fargate

ECS Fargate runs containers without managing EC2 instances.

The tasks:

- Run in private subnets
- Have no public IP addresses
- Receive traffic only from the ALB security group
- Use autoscaling
- Send logs to CloudWatch
- Use least-privilege IAM roles

### 19.8 RDS PostgreSQL

RDS runs in isolated database subnets.

Security features include:

- No public access
- KMS encryption
- Secrets Manager-managed credentials
- SSL enforcement
- PostgreSQL logging
- Enhanced monitoring
- Automated backups
- Multi-AZ in production
- Deletion protection in production

Only the ECS application security group should be able to connect on port `5432`.

### 19.9 Security services

The project enables:

| Service | Purpose |
|---|---|
| GuardDuty | Detect suspicious AWS activity |
| Security Hub | Centralize security findings |
| Inspector | Scan ECR and supported compute resources |
| AWS Config | Detect configuration drift |
| CloudWatch | Store logs and generate alarms |
| SNS | Send notifications |

### 19.10 IAM controls

The IAM module includes:

- Permission boundary
- MFA-protected break-glass role
- Example Service Control Policy
- Restricted workload roles

The break-glass role is for emergency use only.

---

## 20. Verify the deployment

Display outputs:

```powershell
terraform output
```

List ECS clusters:

```powershell
aws ecs list-clusters
```

Describe the ECS service:

```powershell
aws ecs describe-services `
  --cluster YOUR_CLUSTER_NAME `
  --services YOUR_SERVICE_NAME
```

Check RDS:

```powershell
aws rds describe-db-instances `
  --query "DBInstances[].{Name:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address}" `
  --output table
```

Check the ALB:

```powershell
aws elbv2 describe-load-balancers `
  --query "LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" `
  --output table
```

Check GuardDuty:

```powershell
aws guardduty list-detectors
```

Check Security Hub:

```powershell
aws securityhub describe-hub
```

---

## 21. Test the application

Find the ALB or application DNS name:

```powershell
terraform output
```

Test the health endpoint:

```powershell
curl.exe https://app.example.com/health
```

Expected response:

```json
{"status":"healthy"}
```

Test HTTP redirection:

```powershell
curl.exe -I http://app.example.com
```

Expected result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://app.example.com/
```

---

## 22. Verify the Zero Trust security controls

### ECS tasks

Confirm:

```text
assignPublicIp = DISABLED
```

### RDS

Confirm:

```text
PubliclyAccessible = false
StorageEncrypted = true
```

### Security group flow

Expected traffic:

```text
Allowed public IP
        ↓ HTTPS 443
ALB security group
        ↓ TCP 8080
Application security group
        ↓ TCP 5432
Database security group
```

The database should not allow direct traffic from:

- `0.0.0.0/0`
- Your home public IP
- The ALB security group
- Random VPC resources

Only the application security group should be allowed.

### S3

Confirm:

- Public access blocked
- Versioning enabled
- KMS encryption enabled
- HTTPS required

### CloudTrail

Confirm:

- Logging enabled
- Multi-region enabled
- Log validation enabled
- S3 delivery working

---

## 23. Run the repository tests

Return to the repository root:

```powershell
cd ..\..
```

Run formatting checks:

```powershell
terraform fmt -check -recursive
```

Validate lab:

```powershell
cd examples\lab
terraform init -backend=false
terraform validate
cd ..\..
```

Validate production:

```powershell
cd examples\production
terraform init -backend=false
terraform validate
cd ..\..
```

Run the RDS module tests:

```powershell
cd modules\rds
terraform init -backend=false
terraform test
cd ..\..
```

Run the network module tests:

```powershell
cd modules\network
terraform init -backend=false
terraform test
cd ..\..
```

Run Python tests:

```powershell
python -m pip install pytest
python -m pytest tests\python -q
```

Other repository checks may include:

- Checkov
- TFLint
- Secret scanning
- YAML and JSON validation
- Validation shell script

---

## 24. Configure a production remote backend

Terraform state records what Terraform created.

Local state is stored in:

```text
terraform.tfstate
```

For production, use an encrypted S3 backend.

Set variables:

```powershell
$Region = "ap-northeast-1"
$StateBucket = "ritesh-zero-trust-tfstate-UNIQUE-NUMBER"
```

Create the state bucket:

```powershell
aws s3api create-bucket `
  --bucket $StateBucket `
  --region $Region `
  --create-bucket-configuration LocationConstraint=$Region
```

Enable versioning:

```powershell
aws s3api put-bucket-versioning `
  --bucket $StateBucket `
  --versioning-configuration Status=Enabled
```

Block public access:

```powershell
aws s3api put-public-access-block `
  --bucket $StateBucket `
  --public-access-block-configuration `
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Create a DynamoDB lock table:

```powershell
aws dynamodb create-table `
  --table-name terraform-locks `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region $Region
```

Create `backend.hcl`:

```hcl
bucket         = "ritesh-zero-trust-tfstate-UNIQUE-NUMBER"
key            = "zero-trust/lab/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
dynamodb_table = "terraform-locks"
```

Initialize the backend:

```powershell
terraform init -reconfigure -backend-config=backend.hcl
```

---

## 25. How the project was likely developed

A practical development sequence is:

### Phase 1: Define the architecture

Decide:

- What should be public?
- What must remain private?
- Which traffic paths are required?
- What data is sensitive?
- What should be logged?
- How should administrators connect?

### Phase 2: Create the repository structure

```text
modules/
examples/
docs/
tests/
.github/workflows/
```

### Phase 3: Build networking

Create:

- VPC
- Subnets
- Internet Gateway
- NAT Gateway
- Route tables
- VPC endpoints
- Flow Logs

### Phase 4: Add encryption

Create separate KMS keys.

### Phase 5: Add centralized logging

Create protected S3 buckets and CloudWatch log groups.

### Phase 6: Add CloudTrail

Capture AWS API activity.

### Phase 7: Add the application edge

Create WAF, ALB, HTTPS listeners, target groups, and security groups.

### Phase 8: Add ECS

Deploy private Fargate tasks with limited IAM permissions.

### Phase 9: Add RDS

Deploy PostgreSQL in isolated subnets with encryption and Secrets Manager.

### Phase 10: Add security monitoring

Enable:

- AWS Config
- GuardDuty
- Security Hub
- Inspector

### Phase 11: Add IAM controls

Create permission boundaries and emergency access roles.

### Phase 12: Add automated tests

Test security rules such as:

- ECS has no public IP
- RDS is not public
- Encryption is enabled
- Database does not allow `0.0.0.0/0`
- CloudTrail is enabled
- VPC Flow Logs are enabled

### Phase 13: Add CI

GitHub Actions validates the Terraform code without deploying automatically.

---

## 26. Destroy the environment

From the same example directory used for deployment:

```powershell
terraform plan -destroy
```

Review the plan.

Then destroy:

```powershell
terraform destroy
```

Enter:

```text
yes
```

Afterward, check manually for:

- S3 log buckets containing objects
- ECR repositories and images
- KMS keys scheduled for deletion
- Terraform state bucket
- DynamoDB lock table
- ACM certificates
- Route 53 records

Some logging buckets and KMS keys may need manual cleanup.

---

## 27. Recommended learning order

Follow this order:

1. Learn basic Terraform syntax.
2. Run `terraform validate` without deploying.
3. Study the network module.
4. Study the security groups.
5. Build and push a simple test container.
6. Prepare an ACM certificate.
7. Configure the lab variables.
8. Run `terraform plan`.
9. Review the plan carefully.
10. Apply the lab environment.
11. Verify each AWS service.
12. Run security tests.
13. Destroy the lab.
14. Study the production environment only after understanding the lab.

The most important concept is that this project is not one large Terraform file. It is a group of focused modules connected through explicit inputs and outputs.

The root configuration passes values such as:

- VPC IDs
- Subnet IDs
- Security group IDs
- S3 bucket ARNs
- KMS key ARNs
- Target group ARNs
- ECS cluster information

from one module to another.
