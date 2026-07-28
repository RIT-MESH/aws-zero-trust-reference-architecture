# Beginner’s Guide: AWS Zero Trust Reference Architecture

Repository: `RIT-MESH/aws-zero-trust-reference-architecture`

## Table of contents

- [0. Before you begin (read this first)](#0-before-you-begin-read-this-first)
- [1. What this project builds](#1-what-this-project-builds)
- [2. Repository structure](#2-repository-structure)
- [3. Cost warning](#3-cost-warning)
- [4. Install the required tools](#4-install-the-required-tools)
- [5. Clone the repository](#5-clone-the-repository)
- [6. Understand the Terraform files](#6-understand-the-terraform-files)
- [7. Configure AWS authentication](#7-configure-aws-authentication)
- [8. Choose lab or production](#8-choose-lab-or-production)
- [9. Create the variables file](#9-create-the-variables-file)
- [10. Understand the network design](#10-understand-the-network-design)
- [11. Create a simple application container](#11-create-a-simple-application-container)
- [12. Create an ECR repository](#12-create-an-ecr-repository)
- [13. Create an ACM certificate](#13-create-an-acm-certificate)
- [14. Restrict incoming traffic](#14-restrict-incoming-traffic)
- [15. Initialize Terraform](#15-initialize-terraform)
- [16. Format and validate](#16-format-and-validate)
- [17. Create and review a Terraform plan](#17-create-and-review-a-terraform-plan)
- [18. Apply the infrastructure](#18-apply-the-infrastructure)
- [19. Major components explained](#19-major-components-explained)
- [20. Verify the deployment](#20-verify-the-deployment)
- [21. Test the application](#21-test-the-application)
- [22. Verify the Zero Trust security controls](#22-verify-the-zero-trust-security-controls)
- [23. Run the repository tests](#23-run-the-repository-tests)
- [24. Configure a production remote backend](#24-configure-a-production-remote-backend)
- [25. How the project was likely developed](#25-how-the-project-was-likely-developed)
- [26. Destroy the environment](#26-destroy-the-environment)
- [27. Recommended learning order](#27-recommended-learning-order)
- [28. Glossary](#28-glossary)
- [29. Troubleshooting (common errors)](#29-troubleshooting-common-errors)
- [30. Self-test questions](#30-self-test-questions)
- [31. Where to learn the basics first](#31-where-to-learn-the-basics-first)

---

## 0. Before you begin (read this first)

> **Note about the commands in this guide:** every command is written for
> **Windows PowerShell**. Long commands use the backtick `` ` `` to continue on
> the next line. On macOS/Linux (bash/zsh) replace the backtick with a backslash
> `\`, and replace `Get-ChildItem` with `ls`, `Copy-Item` with `cp`, `notepad`
> with `nano`/`vim`. The Terraform and AWS CLI commands themselves are identical
> on every OS.

### Who this guide is for

You can follow this guide even if you have never used AWS or Terraform before.
It explains each step with copy-paste commands and plain-language notes. You do
not need to be a security expert.

**Expected effort for the lab environment:**

- Time: about 2–4 hours end to end (most of it is waiting for AWS to create
  resources and reviewing the plan).
- Difficulty: intermediate. You should be comfortable installing software and
  using a terminal, but no prior AWS or Terraform knowledge is assumed.

### A 10-step fast path

If the 27 steps feel like a lot, here is the short version. Each links to the
detailed section so you can go deeper when you need to.

1. Install AWS CLI, Terraform, Git ([Section 4](#4-install-the-required-tools)).
2. Clone this repository ([Section 5](#5-clone-the-repository)).
3. Log in to AWS ([Section 7](#7-configure-aws-authentication)).
4. Go to `examples/lab` ([Section 8](#8-choose-lab-or-production)).
5. Fill in `terraform.tfvars` ([Section 9](#9-create-the-variables-file)).
6. Build and push a container image ([Sections 11–12](#11-create-a-simple-application-container)).
7. Create an HTTPS certificate ([Section 13](#13-create-an-acm-certificate)).
8. `terraform init` then `terraform plan` ([Sections 15–17](#15-initialize-terraform)).
9. `terraform apply` ([Section 18](#18-apply-the-infrastructure)).
10. Verify, then `terraform destroy` when done ([Sections 20, 26](#20-verify-the-deployment)).

### What is Zero Trust?

Old security was a castle: strong walls (the firewall) around everything, and
once you were *inside* the network you were trusted. If an attacker got past the
gate, they could roam freely.

Zero Trust is the opposite: **never trust, always verify.** It assumes the
network is already hostile and checks *every* request as if it came from the
public internet, no matter where it originated. Three ideas drive it:

- **Verify explicitly** — every request is authenticated and authorized.
- **Least privilege** — give the minimum access needed, nothing more.
- **Assume breach** — design as if an attacker is already inside.

### Real-world analogy

Think of this architecture as a secure office building. You need the right
keycard at *every* door, not just the front one. That is the heart of Zero Trust.

| AWS component | Office building equivalent |
|---|---|
| AWS WAF | Guard at the front gate |
| Application Load Balancer | Reception desk directing visitors |
| ECS Fargate (the app) | Workers inside locked rooms |
| RDS PostgreSQL | The vault |
| Security groups | Keycards that open only specific doors |
| CloudTrail | Security cameras (who did what) |
| GuardDuty | Burglar alarm |
| KMS | The locked key cabinet |

### One idea to hold onto

This project is **not** one giant configuration file. It is many small, focused
pieces (called *modules*) connected through explicit inputs and outputs. If you
understand that one idea, the whole repository makes sense.

---

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


### The architecture as a picture

```mermaid
flowchart TD
    Internet([Internet]) --> WAF[AWS WAF]
    WAF --> ALB[Application Load Balancer]
    ALB -->|HTTPS 443| ECS[ECS Fargate app<br/>private subnets]
    ECS -->|TCP 5432| RDS[(RDS PostgreSQL<br/>isolated subnets)]
    ECS -.->|VPC endpoints| AWS[AWS services<br/>SSM, ECR, KMS, Logs]
    subgraph Monitoring[Security & monitoring]
        CT[CloudTrail]
        GD[GuardDuty]
        SH[Security Hub]
        CW[CloudWatch]
    end
    CT --> S3[(Encrypted S3<br/>log bucket)]
    GD --> SH
    SH --> CW
end
```

The app and the database never get public IP addresses. Traffic is only allowed
along the arrows above.

---
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

### Alternative: access keys (for learning only)

Setting up AWS IAM Identity Center (SSO) can itself take time. For a quick
learning sandbox you may instead use long-lived access keys. **Only do this on a
dedicated learning AWS account, never on a production account.**

```powershell
aws configure
```

Enter the Access Key ID, Secret Access Key, default region (for example
`ap-northeast-1`), and output format `json`. Then verify:

```powershell
aws sts get-caller-identity
```

If you go this route, create the key in the IAM console under a user with limited
permissions, and delete the key when you finish.

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

### Lab vs. production at a glance

| Setting | Lab | Production |
|---|---|---|
| Monthly cost (approx.) | USD 120–180 | USD 300–450+ |
| NAT Gateways | 1 (shared) | 1 per Availability Zone |
| ECS tasks | 1 | 3 |
| RDS | Single instance | Multi-AZ |
| RDS deletion protection | Off | On |
| Log retention | Short | Long |
| Purpose | Learn safely | Mirror a real workload |

Start with the lab. Move to production only after you understand every line of
the lab configuration.

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

### What is Terraform state (and why it matters)?

Terraform **state** (`terraform.tfstate`) is a JSON file that records everything
Terraform has created so it can update or destroy it later. A few things a
beginner must know:

- **Never edit it by hand.** Let Terraform change it.
- **It can contain secrets** — for example the RDS database password. So never
  commit it to Git. This repository's `.gitignore` already excludes
  `terraform.tfstate`.
- **Do not lose it.** If you delete state, Terraform forgets what it created and
  you must clean up resources manually in the AWS console.
- For anything beyond a first local test, keep state in the encrypted remote
  backend described in [Section 24](#24-configure-a-production-remote-backend).

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

### What success looks like

If everything worked, you should be able to confirm all of these:

- `terraform output` shows an ALB DNS name, a VPC ID, an ECS cluster name, an
  RDS endpoint, and a break-glass role ARN.
- `aws ecs describe-services` shows the ECS service with `RUNNING` tasks.
- `aws rds describe-db-instances` shows the database as `available`.
- Visiting the ALB DNS `/health` returns `{"status":"healthy"}` (see
  [Section 21](#21-test-the-application)).
- `aws guardduty list-detectors` returns a detector, and
  `aws securityhub describe-hub` succeeds.

If any of these fail, jump to [Section 29 Troubleshooting](#29-troubleshooting-common-errors).


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

### Exact commands for leftover resources

Terraform destroys most things, but some resources protect themselves and must
be removed manually. Run these from your lab/production directory. Replace the
placeholder names with your own.

```powershell
# 1. Empty and delete S3 log buckets (they cannot be deleted while non-empty)
$Bucket = "zt-lab-logs-UNIQUE"
aws s3 rm "s3://$Bucket" --recursive
aws s3api delete-bucket --bucket $Bucket

# 2. Delete the Terraform state bucket and lock table
aws s3 rm "s3://ritesh-zero-trust-tfstate-UNIQUE-NUMBER" --recursive
aws s3api delete-bucket --bucket "ritesh-zero-trust-tfstate-UNIQUE-NUMBER"
aws dynamodb delete-table --table-name terraform-locks

# 3. Schedule KMS keys for deletion (window 7 days)
aws kms list-aliases --query "Aliases[?AliasName!='alias/aws/*].TargetKeyId" --output text
aws kms schedule-key-deletion --key-id YOUR_KEY_ID --pending-window-in-days 7

# 4. Delete the ECR repository (must be empty first)
aws ecr delete-repository --repository-name zero-trust-app --force

# 5. ACM certificates: cannot be deleted while attached to the ALB.
#    Destroy Terraform first; any certificate still listed is usually safe to remove.
aws acm list-certificates
aws acm delete-certificate --certificate-arn YOUR_CERT_ARN

# 6. Route 53 records you created manually
aws route53 list-hosted-zones
# aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID --change-batch file://delete.json
```

Always check your AWS billing dashboard a day later to confirm charges stopped.

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


---

## 28. Glossary

| Term | Plain meaning |
|---|---|
| AWS | Amazon's cloud platform where you rent servers and services |
| Region | A geographic AWS data-center area, e.g. `ap-northeast-1` (Tokyo) |
| VPC | Your own private network inside AWS |
| Subnet | A slice of a VPC |
| Public subnet | A subnet that can reach the internet |
| Private subnet | A subnet with no direct internet path |
| Isolated subnet | A subnet with no internet path at all |
| Security group | A firewall rule attached to a resource |
| NACL | Network-level firewall for a subnet |
| IAM | AWS's user and permission system |
| IAM Identity Center / SSO | Single sign-on for AWS users |
| MFA | Multi-factor authentication (a second factor, e.g. an app code) |
| ECS | Service that runs containers on AWS |
| Fargate | Serverless container hosting (no EC2 servers to manage) |
| ALB | Application Load Balancer; distributes incoming web traffic |
| WAF | Web Application Firewall; blocks bad requests |
| RDS | Managed relational database (PostgreSQL here) |
| KMS | Key Management Service; creates/stores encryption keys |
| CloudTrail | Audit log of every action taken in AWS |
| CloudWatch | Logs, metrics, and alarms |
| GuardDuty | Threat-detection service (the burglar alarm) |
| Security Hub | Central view of security findings |
| Inspector | Vulnerability scanner for ECR and compute |
| AWS Config | Records resource configuration and drift |
| S3 | Object storage (like a big file server) |
| ECR | Container image registry (Docker images) |
| ACM | AWS Certificate Manager; TLS/SSL certificates |
| SSM | Systems Manager; manage instances and parameters |
| Secrets Manager | Stores and rotates secrets like DB passwords |
| SNS | Notification service |
| VPC endpoint | Reach AWS services without going over the public internet |
| NAT Gateway | Lets private subnets reach the internet for updates |
| IGW | Internet Gateway; connects a VPC to the internet |
| CIDR | A network range written like `10.20.0.0/16` |
| Terraform | Tool that turns code into real cloud resources |
| IaC | Infrastructure as Code; describing infrastructure in files |
| Module | A reusable, self-contained Terraform package |
| State | Terraform's record of what it created |
| Provider | Terraform plugin that talks to a service (e.g. AWS) |
| Plan | A preview of changes Terraform will make |
| Apply | Execute the changes |
| Destroy | Tear down everything Terraform created |
| SCP | Service Control Policy; an organization-level permission guardrail |
| Break-glass role | Emergency admin access used only when normal access fails |

---

## 29. Troubleshooting (common errors)

| Symptom | Likely cause | Fix |
|---|---|---|
| `terraform init` hangs or fails downloading the AWS provider | Network/TLS issue or no credentials | Re-run `aws sts get-caller-identity`; if it fails, re-login. Try `terraform init -upgrade`. |
| `AccessDenied` / `AuthorizationHeaderMalformed` | AWS session expired | Re-run `aws sso login --profile zero-trust-lab` (or `aws configure`). |
| `Error: creating EC2 VPC: UnauthorizedOperation` | IAM user/role lacks permissions | Use an admin-equivalent role for learning; check `aws sts get-caller-identity`. |
| `Error: acquiring lock: ... DynamoDB` | Another `apply`/`plan` holds the state lock | Wait, or remove a stale lock: `terraform force-unlock <LOCK_ID>` (only if you are sure nothing else is running). |
| `docker: Cannot connect to the Docker daemon` | Docker Desktop not running | Start Docker Desktop, then `docker version`. |
| `terraform validate` reports module errors | A referenced module path is wrong or not initialized | Run `terraform init` in that example directory first. |
| `Error: InvalidProviderConfigKey` / provider version mismatch | Terraform or AWS Provider too old | Use Terraform >= 1.6 and AWS Provider 5.x (see [Section 4](#4-install-the-required-tools)). |
| ACM certificate stuck at `PENDING_VALIDATION` | DNS validation CNAME not added | Add the CNAME record in Route53/your DNS provider, then re-check status. |
| ALB `/health` returns 502/503 | ECS task not running or health check failing | `aws ecs describe-services`; confirm tasks are `RUNNING` and the app listens on `8080` at `/health`. |
| `terraform destroy` fails on S3 bucket not empty | Bucket has objects | `aws s3 rm s3://BUCKET --recursive` then destroy again (see [Section 26 cleanup](#26-destroy-the-environment)). |
| Charges continue after destroy | Orphaned resources (NAT, EIP, RDS, KMS) | Check billing dashboard and the manual cleanup commands in [Section 26](#26-destroy-the-environment). |
| `Error: modifying KMS Key Policy: ... AccessDenied` | Key is managed by another account/service | Leave the default AWS-owned key, or grant your role `kms:*` on the key. |
| `git clone` fails with TLS error | Old git using schannel | `git -c http.sslBackend=openssl clone ...` or update Git for Windows. |

If a command fails and you are not sure why, read the full error (not just the
last line) — Terraform usually names the exact resource and the reason.

---

## 30. Self-test questions

Answer these to check your understanding. If you can answer most, you understand
the architecture, not just the steps.

1. In your own words, what does "Zero Trust" mean, and how is it different from a
   traditional firewall-only network?
2. Why are the ECS tasks given **no public IP address**, even though they serve a
   public website?
3. Why is the RDS database placed in an **isolated** subnet instead of a private
   one?
4. Which security group is allowed to talk to the database on port `5432`, and
   why not the ALB's security group directly?
5. What does `terraform.tfstate` contain, and why must you never commit it to
   Git?
6. What is the difference between `terraform plan` and `terraform apply`? Why
   run plan first?
7. Why does the project use separate KMS keys for logs, RDS, and S3 instead of
   one shared key?
8. What does CloudTrail record, and why does that matter for security?
9. Name two reasons the lab configuration is cheaper than production.
10. After `terraform destroy`, which resources might still exist and need manual
    cleanup?

---

## 31. Where to learn the basics first

If you realize you need the fundamentals before tackling this project, these
free resources are good starting points:

- **AWS basics** — AWS Cloud Practitioner essentials (AWS Skill Builder, free).
- **Terraform basics** — HashiCorp's "Get started with Terraform" tutorials at
  `https://developer.hashicorp.com/terraform/tutorials`.
- **Docker basics** — Docker's "Get started" guide at `https://docs.docker.com/get-started/`.
- **Networking basics** — any short "IP addresses, subnets, and CIDR" explainer;
  you only need the intuition, not the math.
- **AWS security basics** — the AWS Well-Architected Security pillar whitepaper.

You do not need all of these before starting. Read the first one or two, then
come back to this guide and learn the rest as you go.