# Phase 1: Bootstrap S3 bucket for remote state (with native S3 locking)
# Requires Terraform >= 1.10
# State: LOCAL — terraform.tfstate lives on your machine

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "Demo"
      Project     = "terraform-state-demo"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "terraform-state-${local.account_id}-demo"
}

# S3 Bucket for Remote State Store
resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name    = local.bucket_name
    Purpose = "Terraform Remote State"
  }
}

# Versioning — retain every state file version
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Outputs — copy these into Phase 2 backend block
output "state_bucket_name" {
  description = "S3 bucket name for Phase 2 backend"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_region" {
  description = "Region of the state bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "next_step" {
  description = "Instructions for Phase 2"
  value       = <<-EOT

    Bootstrap complete!

    Update 02-infrastructure/main.tf backend block with:

      bucket       = "${aws_s3_bucket.terraform_state.bucket}"
      region       = "${aws_s3_bucket.terraform_state.region}"
      use_lockfile = true

    Then run: terraform init
  EOT
}
