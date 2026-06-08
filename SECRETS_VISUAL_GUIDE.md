# Secrets Flow Visual Guide

## TL;DR: 4 Secrets You Need

```
BOOTSTRAP OUTPUT                 GITHUB SECRETS                CI/CD USES
════════════════════════════════════════════════════════════════════════════

arn:aws:iam::123456789012:role/
github-actions-terraform-role    AWS_ROLE_TO_ASSUME      →  AWS authentication
                                                             ┌────────────────┐
                                                             │ assume-role    │
                                                             └────────────────┘

us-east-1                        AWS_REGION              →  AWS region for calls
                                                             ┌────────────────┐
                                                             │ ec2, eks, etc  │
                                                             └────────────────┘

purely-terraform-state           TF_STATE_BUCKET         →  Terraform state file
                                                             ┌────────────────┐
                                                             │ S3 storage     │
                                                             └────────────────┘

purely-terraform-locks           TF_LOCK_TABLE           →  Lock concurrent ops
                                                             ┌────────────────┐
                                                             │ DynamoDB       │
                                                             └────────────────┘
```

---

## After Bootstrap: Your Output Will Look Like This

```bash
================================================
✓ Bootstrap setup complete!
================================================

Add these secrets to GitHub repository:
  Repository → Settings → Secrets and variables → Actions

AWS_ROLE_TO_ASSUME
  arn:aws:iam::123456789012:role/github-actions-terraform-role
              ↑ Your account ID goes here

AWS_REGION
  us-east-1

TF_STATE_BUCKET
  purely-terraform-state

TF_LOCK_TABLE
  purely-terraform-locks
```

---

## GitHub Secrets Setup (Exact Steps)

### Step 1: Go to Settings
```
https://github.com/YOUR_ORG/Fullstack-E-commerce-web-application/settings/secrets/actions
```

### Step 2: Add Secret #1
```
Click: New repository secret

Name:  AWS_ROLE_TO_ASSUME
Value: arn:aws:iam::123456789012:role/github-actions-terraform-role
       (copy from bootstrap output)

Click: Add secret
```

### Step 3: Add Secret #2
```
Click: New repository secret

Name:  AWS_REGION
Value: us-east-1

Click: Add secret
```

### Step 4: Add Secret #3
```
Click: New repository secret

Name:  TF_STATE_BUCKET
Value: purely-terraform-state

Click: Add secret
```

### Step 5: Add Secret #4
```
Click: New repository secret

Name:  TF_LOCK_TABLE
Value: purely-terraform-locks

Click: Add secret
```

### Result
You should see:
```
✓ AWS_REGION                (Updated X seconds ago)
✓ AWS_ROLE_TO_ASSUME        (Updated X seconds ago)
✓ TF_LOCK_TABLE             (Updated X seconds ago)
✓ TF_STATE_BUCKET           (Updated X seconds ago)
```

---

## How CI/CD Uses These Secrets

### In `.github/workflows/ci-cd-tf-plan.yml`

```yaml
name: Terraform Plan

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}    ← Secret #1
          aws-region: ${{ secrets.AWS_REGION }}                ← Secret #2

      - name: Terraform Init
        run: terraform init \
          -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \    ← Secret #3
          -backend-config="region=${{ secrets.AWS_REGION }}" \         ← Secret #2
          -backend-config="dynamodb_table=${{ secrets.TF_LOCK_TABLE }}"  ← Secret #4

      - name: Terraform Plan
        run: terraform plan -out=tfplan
```

**Flow:**
1. GitHub reads Secret #1 (role ARN)
2. Assumes that role to get temporary AWS credentials
3. Uses Secret #2 (region) for AWS API calls
4. Initializes Terraform backend using Secrets #3 & #4
5. Runs terraform plan with those credentials

---

## The Complete Secret-to-Action Flow

```
┌─────────────────────────────────────┐
│ 1. Bootstrap Creates Resources      │
├─────────────────────────────────────┤
│ • S3: purely-terraform-state        │
│ • DynamoDB: purely-terraform-locks  │
│ • IAM Role: github-actions-...      │
│ • OIDC Provider: for GitHub auth    │
└──────────────┬──────────────────────┘
               │
               ↓ (outputs values)
┌──────────────────────────────────────────┐
│ 2. You Add 4 GitHub Secrets              │
├──────────────────────────────────────────┤
│ AWS_ROLE_TO_ASSUME      = role ARN       │
│ AWS_REGION              = region         │
│ TF_STATE_BUCKET         = s3 bucket      │
│ TF_LOCK_TABLE           = dynamodb table │
└──────────────┬───────────────────────────┘
               │
               ↓ (stored in GitHub)
┌──────────────────────────────────────────┐
│ 3. CI/CD Workflow Reads Secrets          │
├──────────────────────────────────────────┤
│ ${{ secrets.AWS_ROLE_TO_ASSUME }}        │
│ ${{ secrets.AWS_REGION }}                │
│ ${{ secrets.TF_STATE_BUCKET }}           │
│ ${{ secrets.TF_LOCK_TABLE }}             │
└──────────────┬───────────────────────────┘
               │
               ↓ (injects into commands)
┌──────────────────────────────────────────┐
│ 4. Terraform Connects to AWS             │
├──────────────────────────────────────────┤
│ aws-actions/configure-aws-credentials:   │
│   Assumes role (Secret #1)               │
│   Gets temporary credentials             │
│                                          │
│ terraform init:                          │
│   Connects to S3 (Secret #3)             │
│   Uses DynamoDB for locks (Secret #4)    │
│                                          │
│ terraform plan/apply:                    │
│   Creates infrastructure on AWS          │
└──────────────┬───────────────────────────┘
               │
               ↓
           DEPLOYED! ✅
```

---

## Verification Commands

### Check if Secrets Exist (GitHub CLI)
```bash
gh secret list

# Output should show:
# AWS_REGION                Updated 2 minutes ago
# AWS_ROLE_TO_ASSUME        Updated 1 minute ago
# TF_LOCK_TABLE             Updated 1 minute ago
# TF_STATE_BUCKET           Updated 3 minutes ago
```

### Check if AWS Resources Exist
```bash
# S3 bucket
aws s3 ls | grep terraform-state
# Output: 2026-06-08 12:34:56 purely-terraform-state

# DynamoDB table
aws dynamodb list-tables | jq '.TableNames[]' | grep locks
# Output: "purely-terraform-locks"

# IAM role
aws iam get-role --role-name github-actions-terraform-role
# Output: Role ARN, Created date, etc.
```

---

## One-Page Reference

| Secret Name | Bootstrap Source | GitHub Destination | CI/CD Use Case |
|-------------|------------------|--------------------|-----------------|
| `AWS_ROLE_TO_ASSUME` | Role ARN created by bootstrap | `role-to-assume` in workflow | Authenticate to AWS |
| `AWS_REGION` | Your tfvars file | `aws-region` in workflow | AWS API operations |
| `TF_STATE_BUCKET` | S3 bucket created by bootstrap | Terraform backend init | Store state file |
| `TF_LOCK_TABLE` | DynamoDB table created by bootstrap | Terraform backend init | Prevent concurrent runs |

---

## What NOT to Do

❌ **Don't hardcode** these values in workflows
```yaml
# WRONG ❌
with:
  role-to-assume: arn:aws:iam::123456789012:role/github-actions-terraform-role
```

✅ **Do use secrets** instead
```yaml
# CORRECT ✅
with:
  role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
```

❌ **Don't commit tfvars** with real values
```bash
# WRONG ❌
git add terraform/terraform.tfvars
git commit -m "add credentials"
```

✅ **Do use .gitignore**
```bash
# Already in .gitignore ✅
*.tfvars
*.tfvars.json
```

---

## Next Action

You have 2 options:

### Option A: Automated (Recommended)
```bash
chmod +x scripts/bootstrap-terraform.sh
./scripts/bootstrap-terraform.sh
# Script will handle everything!
```

### Option B: Step-by-Step
1. `cd bootstrap && terraform apply`
2. Copy outputs
3. Manually add 4 GitHub Secrets
4. `cd terraform && terraform init`

**Either way, you'll have the 4 secrets ready in ~5 minutes!** 🚀
