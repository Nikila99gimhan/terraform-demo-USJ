# Terraform Demo: Local State → Remote S3 Backend

A hands-on demo showing Terraform fundamentals — from local state to a fully remote S3-backed state with native locking (no DynamoDB required).

---

## Project Structure

```
terraform-demo/
├── 01-bootstrap/
│   └── main.tf         # Creates S3 bucket for remote state — runs with LOCAL state
│
└── 02-infrastructure/
    └── main.tf         # Deploys VPC, EC2, etc. — runs with REMOTE state (S3)
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.10 | [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI | >= 2.x | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| AWS Credentials | Configured | `aws configure` |

**Verify:**
```bash
terraform version
aws sts get-caller-identity
```

---

## Architecture Overview

```
                    Terraform CLI
                         │
                         ▼
              ┌─────────────────────┐
              │   S3 Remote Backend │
              │  terraform.tfstate  │
              │  + native lockfile  │  ← No DynamoDB needed (Terraform >= 1.10)
              └─────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────┐
│                   VPC  10.0.0.0/16         │
│                                            │
│  ┌──────────────────────────────────────┐  │
│  │   Public Subnet  10.0.1.0/24         │  │
│  │                                      │  │
│  │   ┌──────────────────────────────┐   │  │
│  │   │  EC2  t3.micro               │   │  │
│  │   │  Amazon Linux 2023           │   │  │
│  │   │  Apache Web Server           │   │  │
│  │   └──────────────────────────────┘   │  │
│  │   Security Group: 22, 80, 443        │  │
│  └──────────────────────────────────────┘  │
│                                            │
│   Internet Gateway                         │
└────────────────────────────────────────────┘
                    │
                 Internet
```

---

## State: Old vs New

| | Local State | Remote State (old) | Remote State (new, >= 1.10) |
|---|---|---|---|
| Location | Your machine | S3 | S3 |
| Locking | None | DynamoDB | S3 native lockfile |
| Team use | No | Yes | Yes |
| Extra service | — | DynamoDB required | None |
| Cost | Free | ~$0/mo | Free |

---

## Demo Flow

### Phase 1 — Bootstrap (Local State)

**Goal:** Create the S3 bucket that will store remote state.

```bash
cd 01-bootstrap
```

```bash
terraform init     # Download AWS provider
terraform plan     # Preview resources to create
terraform apply    # Create S3 bucket
```

After apply, inspect the local state file created on your machine:
```bash
cat terraform.tfstate
```

Note the output values:
```
state_bucket_name = "terraform-state-<account-id>-demo"
state_bucket_region = "us-east-1"
```

Copy the `state_bucket_name` — you'll need it in Phase 2.

---

### Phase 2 — Infrastructure (Remote State)

**Goal:** Deploy VPC + EC2 with state stored remotely in S3.

```bash
cd ../02-infrastructure
```

**Step 1 — Update the backend block in `main.tf`:**
```hcl
backend "s3" {
  bucket       = "terraform-state-<account-id>-demo"   # paste your bucket name
  key          = "02-infrastructure/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true                                   # S3 native locking
}
```

**Step 2 — Init with remote backend:**
```bash
terraform init
```

You'll see:
```
Successfully configured the backend "s3"!
```

**Step 3 — Deploy:**
```bash
terraform plan
terraform apply
```

Terraform creates 6 resources:
- VPC
- Public Subnet
- Internet Gateway
- Route Table + Association
- Security Group
- EC2 Instance

**Step 4 — Verify:**
```bash
terraform output web_server_url
```

Open the URL in your browser — you'll see the demo page.

**Step 5 — Verify state is in S3:**
```bash
aws s3 ls s3://YOUR_BUCKET_NAME/02-infrastructure/
```

---

## Cleanup

Destroy in reverse order:

```bash
# Phase 2 first
cd 02-infrastructure
terraform destroy

# Then Phase 1
cd ../01-bootstrap
terraform destroy
```

> `force_destroy = true` is set on the S3 bucket so Terraform can delete it even if it contains state files.

---

## Key Concepts

### Terraform Workflow
```
terraform init     → Download providers, connect backend
terraform plan     → Preview changes (nothing is created)
terraform apply    → Create/update/delete resources
terraform destroy  → Remove all managed resources
```

### Why Remote State?
- **Shared** — every team member reads/writes the same state file
- **Versioned** — S3 versioning retains previous state snapshots
- **Locked** — prevents two people from running `apply` at the same time
- **Encrypted** — state files contain sensitive data (IPs, IDs, etc.)

### S3 Native Locking (Terraform >= 1.10)
Terraform uses [S3 Conditional Writes](https://aws.amazon.com/about-aws/whats-new/2024/08/amazon-s3-conditional-writes/) to implement locking.
When a lock is held, a `.tflock` file appears in the bucket alongside the state file.
No DynamoDB table needed.

### Security Best Practices Applied
| Area | Practice |
|------|----------|
| S3 | Versioning, AES256 encryption, public access blocked |
| EC2 | IMDSv2 enforced, EBS encrypted, dynamic AMI lookup |
| Network | Security group with least-privilege ports only |
| Tags | Default tags on all resources via provider |

---

## Useful Commands

```bash
terraform state list                          # list all resources in state
terraform state show aws_instance.web_server  # inspect a specific resource
terraform output                              # show all outputs
terraform fmt                                 # format .tf files
terraform validate                            # validate configuration syntax
```

---

*Built for the USJ Session · Managed with Terraform · Infrastructure as Code*
