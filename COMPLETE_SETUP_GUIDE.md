# Complete Setup: Start to Finish

## Timeline: How to Set Up Everything

---

## Phase 1: Local Preparation (5 minutes)

### Step 1.1: Get Your AWS Account ID
```bash
aws sts get-caller-identity --query Account --output text
```
Output: `123456789012` (save this!)

### Step 1.2: Update Configuration
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform/terraform.tfvars`:
```hcl
aws_account_id = "123456789012"  # ← Replace with your output from 1.1
```

Keep everything else the same (or customize if needed):
```hcl
project_name   = "purely"
environment    = "production"
aws_region     = "us-east-1"
tf_state_bucket           = "purely-terraform-state"
tf_lock_table             = "purely-terraform-locks"
github_actions_role_name  = "github-actions-terraform-role"
```

---

## Phase 2: Create AWS Resources (3 minutes)

### Step 2.1: Run Bootstrap
```bash
chmod +x scripts/bootstrap-terraform.sh
./scripts/bootstrap-terraform.sh
```

### Step 2.2: Follow Prompts
Answer the script's questions:
- GitHub organization/username: `YOUR_ORG` or `YOUR_USERNAME`
- Repository name: `Fullstack-E-commerce-web-application`
- Branch: `main` (or your working branch)

### Step 2.3: Wait for Completion
Script will:
```
✓ Creating OIDC provider...
✓ Creating S3 bucket...
✓ Creating DynamoDB table...
✓ Creating IAM role...
✓ Bootstrap setup complete!
```

Bootstrap will output:
```
Add these secrets to GitHub repository:

AWS_ROLE_TO_ASSUME
  arn:aws:iam::123456789012:role/github-actions-terraform-role

AWS_REGION
  us-east-1

TF_STATE_BUCKET
  purely-terraform-state

TF_LOCK_TABLE
  purely-terraform-locks
```

**Keep this output! You need these values next.**

---

## Phase 3: Add GitHub Secrets (2 minutes)

### Step 3.1: Go to GitHub Repository Settings

1. Go to: `https://github.com/YOUR_ORG/Fullstack-E-commerce-web-application`
2. Click: **Settings** (top menu)
3. Click: **Secrets and variables** (left sidebar)
4. Click: **Actions** (submenu)

### Step 3.2: Add 4 New Secrets

Click **New repository secret** and add each one:

**Secret 1: AWS_ROLE_TO_ASSUME**
```
Name: AWS_ROLE_TO_ASSUME
Value: arn:aws:iam::123456789012:role/github-actions-terraform-role
```

**Secret 2: AWS_REGION**
```
Name: AWS_REGION
Value: us-east-1
```

**Secret 3: TF_STATE_BUCKET**
```
Name: TF_STATE_BUCKET
Value: purely-terraform-state
```

**Secret 4: TF_LOCK_TABLE**
```
Name: TF_LOCK_TABLE
Value: purely-terraform-locks
```

Result should look like:
```
AWS_REGION                Updated 2 seconds ago
AWS_ROLE_TO_ASSUME        Updated 1 second ago
TF_LOCK_TABLE             Updated 3 seconds ago
TF_STATE_BUCKET           Updated 5 seconds ago
```

---

## Phase 4: Initialize Terraform (2 minutes)

### Step 4.1: Terraform Init
```bash
cd terraform
terraform init
```

Output should show:
```
Initializing the backend...

Successfully configured the S3 backend...
```

### Step 4.2: Test Terraform
```bash
terraform plan
```

Should show your EKS infrastructure configuration.

---

## Phase 5: Git Commit & Test CI/CD (2 minutes)

### Step 5.1: Commit Changes
```bash
# From project root
git add terraform/ bootstrap/ scripts/ .github/
git commit -m "feat: configure terraform with bootstrap and CI/CD"
```

### Step 5.2: Create Pull Request
```bash
git push origin your-branch
# Then create PR on GitHub
```

### Step 5.3: Watch CI/CD Run
- Go to **Pull Requests**
- Click your new PR
- Scroll to **Checks** section
- Click **Terraform Plan** workflow
- Watch logs as it:
  - ✅ Authenticates to AWS
  - ✅ Initializes Terraform
  - ✅ Runs validation
  - ✅ Creates plan

Plan output will be posted as a comment on your PR!

### Step 5.4: Merge & Deploy
Once plan looks good:
- Click **Merge pull request**
- Go to **Actions** tab
- **Terraform Apply** workflow will run:
  - ✅ Requires environment approval
  - ✅ Applies infrastructure when approved
  - ✅ Creates all resources

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Local Prep                                          │
│ • Get AWS Account ID                                         │
│ • Edit terraform/terraform.tfvars                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: AWS Resources                                       │
│ • Run: ./scripts/bootstrap-terraform.sh                      │
│ • Creates: S3, DynamoDB, IAM role                            │
│ • Outputs: 4 secret values                                   │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: GitHub Secrets                                      │
│ • Go to: Settings → Secrets and variables → Actions         │
│ • Add: 4 repository secrets                                  │
│ • Copy values from Phase 2 output                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: Terraform Init                                      │
│ • Run: cd terraform && terraform init                        │
│ • Run: terraform plan                                        │
│ • Verify S3 backend configured                              │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 5: CI/CD Test                                          │
│ • Commit changes                                             │
│ • Push to GitHub                                             │
│ • Create PR → terraform plan runs                            │
│ • Merge → terraform apply runs                               │
│ • Approve in environment → Resources created                │
└─────────────────────────────────────────────────────────────┘
```

---

## Verification Checklist

- [ ] AWS Account ID obtained
- [ ] `terraform/terraform.tfvars` updated with account ID
- [ ] Bootstrap script ran successfully
- [ ] 4 GitHub Secrets added
- [ ] `terraform init` succeeded
- [ ] `terraform plan` shows infrastructure
- [ ] PR created and terraform plan ran
- [ ] Plan output visible as PR comment

---

## Troubleshooting by Phase

### Phase 1-2: Bootstrap Issues
```bash
# Verify AWS credentials work
aws sts get-caller-identity

# Check Terraform version
terraform version

# Manually check bootstrap outputs
cd bootstrap
terraform output -json
```

### Phase 3: GitHub Secrets Issues
```bash
# List secrets (GitHub CLI)
gh secret list

# Wrong values? Re-run bootstrap
./scripts/bootstrap-terraform.sh
```

### Phase 4: Terraform Init Issues
```bash
# Check state bucket exists
aws s3 ls | grep terraform-state

# Check DynamoDB table exists
aws dynamodb list-tables | grep locks
```

### Phase 5: CI/CD Failures
Check workflow logs:
- Go to **Actions** tab
- Click failing workflow
- View logs for error messages
- Common issues:
  - Secret not found → Wait 1-2 min, retry
  - AWS auth failed → Verify role ARN
  - Backend init failed → Verify bucket/table names

---

## Total Time: ~15 minutes

| Phase | Time | Task |
|-------|------|------|
| 1 | 5 min | Get account ID, edit tfvars |
| 2 | 3 min | Run bootstrap |
| 3 | 2 min | Add GitHub Secrets |
| 4 | 2 min | Terraform init & plan |
| 5 | 3 min | Commit, push, test CI/CD |

---

## What Happens Next

After this setup, your workflow is:

```
1. Terraform changes
   ↓
2. Git commit & push
   ↓
3. Create PR
   ↓
4. CI/CD runs terraform plan (automatic)
   ↓
5. Review plan in PR comment
   ↓
6. Merge PR
   ↓
7. CI/CD runs terraform apply (requires approval)
   ↓
8. Infrastructure deployed! 🚀
```

No hardcoded values. No manual deployments. Pure Infrastructure as Code!

---

## Need Help?

📖 **Documentation Files:**
- `QUICK_START.md` - 30-second overview
- `TERRAFORM_CONFIG_GUIDE.md` - Configuration details
- `GITHUB_SECRETS_SETUP.md` - Secrets reference
- `AWS_ROLE_PERMISSIONS.md` - What role can do
- `CONFIGURATION_FLOW.md` - How config flows through system

✅ **You're all set!** Start with Phase 1 above.
