# Production Terraform CI/CD Setup Guide

## GitHub Secrets Required

Add the following secrets to your GitHub repository settings:

### 1. AWS Credentials
- **AWS_ROLE_TO_ASSUME**: Full ARN of the IAM role for GitHub Actions
  - Format: `arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform-role`
  - Replace `ACCOUNT_ID` with your AWS account ID

- **AWS_REGION**: AWS region for Terraform operations
  - Example: `us-east-1`

### 2. Terraform State Backend
- **TF_STATE_BUCKET**: S3 bucket name for storing Terraform state
  - Must exist and have versioning enabled
  - Example: `my-company-tf-state`

- **TF_LOCK_TABLE**: DynamoDB table name for state locking
  - Must have `LockID` as partition key
  - Example: `my-company-tf-locks`

## Infrastructure Prerequisite Setup

Before using this CI/CD pipeline, create these AWS resources manually:

### 1. S3 Bucket for Terraform State
```bash
aws s3api create-bucket \
  --bucket my-company-tf-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket my-company-tf-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-server-side-encryption-configuration \
  --bucket my-company-tf-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

aws s3api put-bucket-public-access-block \
  --bucket my-company-tf-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 2. DynamoDB Table for State Locking
```bash
aws dynamodb create-table \
  --table-name my-company-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 3. IAM Role for GitHub Actions

**See `AWS_ROLE_PERMISSIONS.md` for detailed permissions breakdown and setup instructions.**

Quick setup:
```bash
# Create the role with OIDC trust
aws iam create-role \
  --role-name github-actions-terraform-role \
  --assume-role-policy-document file://oidc-trust-policy.json

# Attach the policy
aws iam put-role-policy \
  --role-name github-actions-terraform-role \
  --policy-name terraform-policy \
  --policy-document file://aws-github-actions-policy.json
```

Trust policy (`oidc-trust-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Permissions policy: See `aws-github-actions-policy.json`

## GitHub Environment Setup

Create a "production" environment in your repository settings with:
- Protection rules requiring approval before deployment
- Restricted branches (e.g., only main)
- Required reviewers for approval

## CI/CD Workflow

### Plan Workflow (on Pull Request)
1. Triggered on PR with terraform/** changes
2. Runs `terraform plan`
3. Posts plan output as PR comment
4. Stores plan artifact for review

### Apply Workflow (on Push to main)
1. Triggered on push to main with terraform/** changes
2. Requires environment approval
3. Runs `terraform plan`
4. Applies only on approval
5. Stores outputs as artifacts

## Security Best Practices Implemented

✅ **OIDC-based authentication** - No long-lived credentials
✅ **Remote state management** - S3 + DynamoDB locking
✅ **State encryption** - Server-side encryption enabled
✅ **Environment approval** - Manual approval required before apply
✅ **Plan visibility** - PR comments for transparency
✅ **State locking** - Prevents concurrent modifications
✅ **Versioned state** - S3 versioning for rollback capability
✅ **No auto-approve** - Removed -auto-approve flag

## Monitoring & Logging

Monitor these CloudWatch metrics:
- Terraform apply failures
- State lock contention
- S3 bucket access patterns

Enable CloudTrail for:
- AWS API calls from GitHub Actions role
- S3 state bucket modifications
- DynamoDB lock table operations

## Troubleshooting

If state lock fails:
```bash
aws dynamodb delete-item \
  --table-name my-company-tf-locks \
  --key '{"LockID":{"S":"<bucket>/<key>"}}'
```

To migrate existing state to S3:
```bash
# Pull existing state
terraform state pull > terraform.tfstate

# Push to S3 backend after configuring backend.tf
terraform init  # Confirm migration
```
