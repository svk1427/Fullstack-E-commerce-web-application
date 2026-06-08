# Terraform Configuration & Bootstrap Guide

## Overview

This guide explains how to configure and bootstrap your Terraform infrastructure without hardcoding resource names.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                                                               │
│  terraform/                                                   │
│  ├── terraform.tfvars          (Main config - customize this)│
│  ├── variables-backend.tf      (Define variables)            │
│  ├── backend.tf                (Reference variables)         │
│  └── *.tf files                (Use variables)               │
│                                                               │
│  bootstrap/                                                   │
│  ├── main.tf                   (Creates prerequisites)       │
│  ├── terraform.tfvars          (Bootstrap config)            │
│  └── variables.tf              (Bootstrap variables)         │
│                                                               │
│  scripts/                                                     │
│  └── bootstrap-terraform.sh    (Automated setup)             │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Step 1: Update Configuration

### Edit `terraform/terraform.tfvars`

```hcl
project_name   = "purely"        # Your project name
environment    = "production"    # dev/staging/production
aws_region     = "us-east-1"     # Your AWS region
aws_account_id = "123456789012"  # Your 12-digit AWS account ID

# These names will be created by bootstrap
tf_state_bucket           = "purely-terraform-state"
tf_lock_table             = "purely-terraform-locks"
github_actions_role_name  = "github-actions-terraform-role"
```

### Edit `bootstrap/terraform.tfvars`

Same values as above - keep them synchronized!

---

## Step 2: Run Bootstrap (Automated)

### Option A: Use the Bootstrap Script (Recommended)

```bash
# Make script executable
chmod +x scripts/bootstrap-terraform.sh

# Run bootstrap
./scripts/bootstrap-terraform.sh
```

The script will:
- ✅ Check prerequisites (AWS CLI, Terraform, jq)
- ✅ Create OIDC provider for GitHub
- ✅ Create S3 bucket for state
- ✅ Create DynamoDB table for locks
- ✅ Create IAM role for GitHub Actions
- ✅ Output secrets to add to GitHub
- ✅ Optionally add secrets via `gh` CLI

### Option B: Manual Bootstrap

```bash
cd bootstrap

# Initialize Terraform
terraform init

# Review resources to be created
terraform plan

# Create the resources
terraform apply

# Get outputs
terraform output
```

---

## Step 3: Add GitHub Secrets

The bootstrap script will output the secrets. Add them to:

**Repository → Settings → Secrets and variables → Actions**

```
AWS_ROLE_TO_ASSUME = arn:aws:iam::123456789012:role/github-actions-terraform-role
AWS_REGION = us-east-1
TF_STATE_BUCKET = purely-terraform-state
TF_LOCK_TABLE = purely-terraform-locks
```

Or automatically with GitHub CLI:

```bash
gh secret set AWS_ROLE_TO_ASSUME --body "arn:aws:iam::123456789012:role/github-actions-terraform-role"
gh secret set AWS_REGION --body "us-east-1"
gh secret set TF_STATE_BUCKET --body "purely-terraform-state"
gh secret set TF_LOCK_TABLE --body "purely-terraform-locks"
```

---

## Step 4: Initialize Main Terraform

```bash
cd terraform

# Initialize with backend configuration from variables
terraform init

# Plan to verify
terraform plan

# Apply (or wait for CI/CD)
terraform apply
```

---

## How Variables Are Used

### In CI/CD Workflows

The workflows now reference variables instead of hardcoding values:

```yaml
# Before (hardcoded)
- name: Terraform Init
  run: terraform init

# After (uses GitHub Secrets)
- name: Terraform Init
  run: terraform init \
    -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
    -backend-config="key=terraform.tfstate" \
    -backend-config="region=${{ secrets.AWS_REGION }}" \
    -backend-config="dynamodb_table=${{ secrets.TF_LOCK_TABLE }}"
```

### In Terraform Code

Define once in `variables-backend.tf`, use everywhere:

```hcl
# variables-backend.tf
variable "tf_state_bucket" {
  type = string
}

# backend.tf (references the variable)
backend "s3" {
  bucket = var.tf_state_bucket  # Uses the variable
}

# Any other file
resource "aws_s3_bucket" "data" {
  bucket = var.tf_state_bucket
}
```

---

## Configuration Files Explained

### `terraform/terraform.tfvars`
- Contains actual values (S3 bucket name, DynamoDB table name, etc.)
- Should be **customized per environment**
- Not committed to git (add to .gitignore for secrets)

### `terraform/variables-backend.tf`
- Defines variables (schema, validation, defaults)
- Reusable across environments
- Committed to git

### `bootstrap/main.tf`
- Creates prerequisite AWS resources
- S3 bucket for state
- DynamoDB table for locks
- IAM role with OIDC trust policy

### `scripts/bootstrap-terraform.sh`
- Automated setup wizard
- Creates OIDC provider
- Applies bootstrap Terraform
- Optionally adds GitHub secrets

---

## Environment-Specific Configuration

To manage multiple environments, create separate tfvars files:

```
terraform/
├── terraform.tfvars                (default/production)
├── terraform.dev.tfvars            (development)
├── terraform.staging.tfvars        (staging)
└── variables-backend.tf            (same for all)
```

Then apply with:

```bash
terraform plan -var-file="terraform.dev.tfvars"
terraform apply -var-file="terraform.dev.tfvars"
```

---

## Troubleshooting

### Problem: "Backend initialization failed"

**Solution:** Ensure GitHub Secrets are set correctly:

```bash
# Verify secrets exist
gh secret list

# Re-run bootstrap to get correct values
./scripts/bootstrap-terraform.sh
```

### Problem: "S3 bucket already exists"

**Solution:** Either:
1. Use a different bucket name in `terraform.tfvars`
2. Import existing bucket: `terraform import aws_s3_bucket.terraform_state <bucket-name>`

### Problem: "OIDC provider not found"

**Solution:** Run bootstrap script - it creates the OIDC provider:

```bash
./scripts/bootstrap-terraform.sh
```

### Problem: State file locked

**Solution:** Release the lock:

```bash
aws dynamodb delete-item \
  --table-name purely-terraform-locks \
  --key '{"LockID":{"S":"purely-terraform-state/terraform.tfstate"}}'
```

---

## Security Best Practices

✅ **Never commit credentials** - Add `terraform.tfvars` to `.gitignore` if it contains secrets

✅ **Use different names per environment** - `state-prod`, `state-dev`, `locks-prod`, `locks-dev`

✅ **Enable S3 versioning** - Bootstrap already does this for rollback

✅ **Use state encryption** - Bootstrap enables AES-256 encryption

✅ **Restrict IAM role access** - Bootstrap scopes role to specific GitHub org/repo/branch

✅ **Monitor state access** - S3 logging is enabled, check CloudTrail

---

## Next Steps

1. **Update values** in `terraform/terraform.tfvars`
2. **Run bootstrap**: `./scripts/bootstrap-terraform.sh`
3. **Add GitHub Secrets** from bootstrap output
4. **Initialize main Terraform**: `cd terraform && terraform init`
5. **Push to GitHub** and verify CI/CD works

---

## Reference

| File | Purpose | Customize |
|------|---------|-----------|
| `terraform/terraform.tfvars` | Configuration values | ✅ Yes |
| `terraform/variables-backend.tf` | Variable definitions | ❌ Usually no |
| `terraform/backend.tf` | Backend configuration | ❌ No |
| `bootstrap/main.tf` | Create prerequisites | ❌ No |
| `bootstrap/terraform.tfvars` | Bootstrap values | ✅ Yes (sync with main) |
| `scripts/bootstrap-terraform.sh` | Setup automation | ❌ No |
