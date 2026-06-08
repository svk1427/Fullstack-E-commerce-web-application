locals {
  account_id = data.aws_caller_identity.current.account_id
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.tf_state_bucket

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-terraform-state"
  })
}

# Enable versioning for state rollback
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for state
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable logging for state bucket
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-logs/"
}

# Logging bucket for state bucket
resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "${var.tf_state_bucket}-logs"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-terraform-state-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = var.tf_lock_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery_specification {
    enabled = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-terraform-locks"
  })
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_terraform" {
  name        = var.github_actions_role_name
  description = "Role for GitHub Actions to deploy Terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Inline policy for GitHub Actions role
resource "aws_iam_role_policy" "github_actions_terraform" {
  name   = "${var.github_actions_role_name}-policy"
  role   = aws_iam_role.github_actions_terraform.id
  policy = file("${path.module}/../aws-github-actions-policy.json")
}

# Output the role ARN for GitHub secrets
output "github_actions_role_arn" {
  description = "ARN of GitHub Actions Terraform role for AWS_ROLE_TO_ASSUME secret"
  value       = aws_iam_role.github_actions_terraform.arn
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locks"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "setup_complete" {
  description = "Add these to GitHub Secrets"
  value = {
    AWS_ROLE_TO_ASSUME = aws_iam_role.github_actions_terraform.arn
    AWS_REGION         = var.aws_region
    TF_STATE_BUCKET    = aws_s3_bucket.terraform_state.id
    TF_LOCK_TABLE      = aws_dynamodb_table.terraform_locks.id
  }
}
