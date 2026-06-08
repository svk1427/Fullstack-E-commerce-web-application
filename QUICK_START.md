# Quick Start - Terraform Bootstrap

## 30-Second Overview

You don't need to know bucket names or role names upfront. Everything is:
- ✅ Configured in `terraform/terraform.tfvars`
- ✅ Created automatically by bootstrap script
- ✅ Added to GitHub Secrets automatically

---

## Quick Start (5 minutes)

### 1. Update Configuration

```bash
cd terraform
cat terraform.tfvars.example
```

Edit `terraform/terraform.tfvars`:
- Replace `YOUR_ACCOUNT_ID` with your 12-digit AWS account ID
- Update region if needed (default: us-east-1)
- Keep other values as-is

### 2. Run Bootstrap

```bash
chmod +x scripts/bootstrap-terraform.sh
./scripts/bootstrap-terraform.sh
```

Follow the prompts:
- Enter GitHub org/username
- Enter GitHub repo name
- Enter branch (default: main)

### 3. Done!

Script automatically:
- ✅ Creates OIDC provider
- ✅ Creates S3 bucket for state
- ✅ Creates DynamoDB table for locks
- ✅ Creates IAM role for GitHub
- ✅ Shows secrets to add

If using `gh` CLI, it can add secrets automatically too!

---

## What Gets Created?

| Resource | Name | Purpose |
|----------|------|---------|
| S3 Bucket | `purely-terraform-state` | Store Terraform state |
| S3 Bucket | `purely-terraform-state-logs` | Audit state access |
| DynamoDB Table | `purely-terraform-locks` | Prevent concurrent changes |
| IAM Role | `github-actions-terraform-role` | GitHub Actions authentication |
| OIDC Provider | (auto) | Secure GitHub↔AWS connection |

---

## Manual Bootstrap (If Script Fails)

```bash
# Navigate to bootstrap directory
cd bootstrap

# Show what will be created
terraform plan

# Create resources
terraform apply

# Get outputs
terraform output -json

# Copy values to GitHub Secrets
```

---

## Add GitHub Secrets

**One-time setup** in GitHub:
Settings → Secrets and variables → Actions → New repository secret

Add these 4 secrets (from bootstrap output):
1. `AWS_ROLE_TO_ASSUME` = `arn:aws:iam::...`
2. `AWS_REGION` = `us-east-1`
3. `TF_STATE_BUCKET` = `purely-terraform-state`
4. `TF_LOCK_TABLE` = `purely-terraform-locks`

Or with GitHub CLI:
```bash
./scripts/bootstrap-terraform.sh  # Will offer to do this
```

---

## Initialize Terraform

```bash
cd terraform
terraform init
terraform plan
```

Should show your EKS infrastructure ready to deploy!

---

## Next: Create a Pull Request

```bash
git add terraform/
git commit -m "Configure Terraform with bootstrap"
git push

# Create PR on GitHub
```

CI/CD will run `terraform plan` automatically and post results as a comment!

---

## Files You Need to Know

| File | Edit? | Purpose |
|------|-------|---------|
| `terraform/terraform.tfvars` | ✅ Yes | Your configuration values |
| `terraform/terraform.tfvars.example` | 📖 Reference | Copy from this |
| `bootstrap/terraform.tfvars` | ✅ Sync | Keep in sync with main |
| `scripts/bootstrap-terraform.sh` | 🤖 Auto | Run this script |
| `.github/workflows/ci-cd-tf-*.yml` | ❌ Don't edit | Uses GitHub Secrets |

---

## Troubleshooting

### Script Fails with "AWS CLI not found"
Install AWS CLI: https://aws.amazon.com/cli/

### Script Fails with "terraform not found"
Install Terraform: https://www.terraform.io/downloads.html

### "Invalid AWS Account ID"
- Must be 12 digits: `123456789012`
- Get it: `aws sts get-caller-identity --query Account`

### "No OIDC provider"
Script will create it automatically

### "Secret not showing in Actions"
Wait 1-2 minutes after adding, then re-run workflow

---

## Help & Reference

- **Configuration guide**: See `TERRAFORM_CONFIG_GUIDE.md`
- **Permissions needed**: See `AWS_ROLE_PERMISSIONS.md`
- **Full setup**: See `TERRAFORM_PRODUCTION_SETUP.md`
- **Configuration flow**: See `CONFIGURATION_FLOW.md`

---

That's it! Infrastructure as code, no hardcoded values. 🚀
