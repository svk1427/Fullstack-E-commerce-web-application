# GitHub Secrets Configuration - Complete Guide

## 4 Secrets You Need to Add

After running bootstrap, you'll get outputs. Here's how to map them to GitHub Secrets:

---

## Step 1: Get Values from Bootstrap

Run the bootstrap script:
```bash
./scripts/bootstrap-terraform.sh
```

At the end, it will show something like:

```
================================================
✓ Bootstrap setup complete!
================================================

Add these secrets to GitHub repository:
  Repository → Settings → Secrets and variables → Actions

AWS_ROLE_TO_ASSUME
  arn:aws:iam::846898691042:role/github-actions-terraform-role

AWS_REGION
  us-east-1

TF_STATE_BUCKET
  purely-terraform-state

TF_LOCK_TABLE
  purely-terraform-locks
```

---

## Step 2: Add to GitHub Secrets

### Manual Method (via GitHub UI)

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add 4 secrets:

| Secret Name | Value |
|------------|-------|
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::846898691042:role/github-actions-terraform-role` |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `purely-terraform-state` |
| `TF_LOCK_TABLE` | `purely-terraform-locks` |

### Automatic Method (using GitHub CLI)

```bash
# After bootstrap script completes
gh secret set AWS_ROLE_TO_ASSUME --body "arn:aws:iam::846898691042:role/github-actions-terraform-role"
gh secret set AWS_REGION --body "us-east-1"
gh secret set TF_STATE_BUCKET --body "purely-terraform-state"
gh secret set TF_LOCK_TABLE --body "purely-terraform-locks"
```

Or the bootstrap script will offer to do this automatically!

---

## What Each Secret Does

### `AWS_ROLE_TO_ASSUME`
- **What it is**: IAM role ARN created by bootstrap
- **Where it comes from**: Bootstrap creates this role
- **Used by**: GitHub Actions to authenticate with AWS
- **Example**: `arn:aws:iam::846898691042:role/github-actions-terraform-role`
- **Where used in workflow**: 
  ```yaml
  - name: Configure AWS Credentials
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
  ```

### `AWS_REGION`
- **What it is**: AWS region for your infrastructure
- **Where it comes from**: You specify in `terraform/terraform.tfvars`
- **Used by**: AWS API calls, Terraform operations
- **Example**: `us-east-1`
- **Where used in workflow**:
  ```yaml
  - name: Configure AWS Credentials
    with:
      aws-region: ${{ secrets.AWS_REGION }}
  ```

### `TF_STATE_BUCKET`
- **What it is**: S3 bucket name for storing Terraform state
- **Where it comes from**: Bootstrap creates this bucket
- **Used by**: Terraform backend init
- **Example**: `purely-terraform-state`
- **Where used in workflow**:
  ```yaml
  - name: Terraform Init
    run: terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}"
  ```

### `TF_LOCK_TABLE`
- **What it is**: DynamoDB table name for state locking
- **Where it comes from**: Bootstrap creates this table
- **Used by**: Terraform to prevent concurrent modifications
- **Example**: `purely-terraform-locks`
- **Where used in workflow**:
  ```yaml
  - name: Terraform Init
    run: terraform init -backend-config="dynamodb_table=${{ secrets.TF_LOCK_TABLE }}"
  ```

---

## Complete Workflow: How Secrets Flow

```
1. You run bootstrap script
   ↓
2. Bootstrap creates AWS resources:
   - S3 bucket for state
   - DynamoDB table for locks
   - IAM role for GitHub
   ↓
3. Script outputs values:
   AWS_ROLE_TO_ASSUME=arn:aws:iam::846898691042:role/github-actions-terraform-role
   AWS_REGION=us-east-1
   TF_STATE_BUCKET=purely-terraform-state
   TF_LOCK_TABLE=purely-terraform-locks
   ↓
4. You add these as GitHub Secrets
   ↓
5. GitHub Actions reads secrets from environment:
   ${{ secrets.AWS_ROLE_TO_ASSUME }}
   ${{ secrets.AWS_REGION }}
   ${{ secrets.TF_STATE_BUCKET }}
   ${{ secrets.TF_LOCK_TABLE }}
   ↓
6. CI/CD workflow uses them:
   - Authenticate to AWS with role
   - Connect to S3 bucket for state
   - Use DynamoDB for state locking
   ↓
7. Terraform operations work!
```

---

## Verification: How to Confirm Secrets Are Set

### Check Secrets Exist
```bash
gh secret list
```

Output should show:
```
AWS_REGION        Updated 2026-06-08
AWS_ROLE_TO_ASSUME Updated 2026-06-08
TF_LOCK_TABLE     Updated 2026-06-08
TF_STATE_BUCKET   Updated 2026-06-08
```

### Check Workflow Uses Them
Look at `.github/workflows/ci-cd-tf-plan.yml`:
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: ${{ secrets.AWS_REGION }}

- name: Terraform Init
  run: terraform init \
    -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
    -backend-config="region=${{ secrets.AWS_REGION }}" \
    -backend-config="dynamodb_table=${{ secrets.TF_LOCK_TABLE }}"
```

✅ All secrets referenced in workflow

---

## Example: Real Values After Bootstrap

Assuming your account ID is `987654321098`:

| Secret | Value |
|--------|-------|
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::987654321098:role/github-actions-terraform-role` |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `purely-terraform-state` |
| `TF_LOCK_TABLE` | `purely-terraform-locks` |

---

## Troubleshooting

### "Secrets not found when running workflow"
- Wait 1-2 minutes after adding secrets
- Trigger a new workflow run (push to branch)
- Check secret name spelling (case-sensitive)

### "AssumeRoleUnauthorizedAccess"
- Verify `AWS_ROLE_TO_ASSUME` ARN is correct
- Check bootstrap created the role: `aws iam get-role --role-name github-actions-terraform-role`
- Verify OIDC provider trust policy includes your GitHub org/repo

### "InvalidUserID.Malformed for bucket"
- Verify `TF_STATE_BUCKET` value matches what bootstrap created
- Check bucket exists: `aws s3 ls | grep purely-terraform-state`

### "State lock not working"
- Verify `TF_LOCK_TABLE` exists: `aws dynamodb describe-table --table-name purely-terraform-locks`
- Ensure DynamoDB table has LockID as partition key

---

## Step-by-Step Summary

### ✅ After Bootstrap (You Get These Values):
```
AWS_ROLE_TO_ASSUME = arn:aws:iam::846898691042:role/github-actions-terraform-role
AWS_REGION = us-east-1
TF_STATE_BUCKET = purely-terraform-state
TF_LOCK_TABLE = purely-terraform-locks
```

### ✅ Add to GitHub:
Settings → Secrets and variables → Actions → Add 4 new secrets

### ✅ Workflow Automatically Uses Them:
```yaml
${{ secrets.AWS_ROLE_TO_ASSUME }}
${{ secrets.AWS_REGION }}
${{ secrets.TF_STATE_BUCKET }}
${{ secrets.TF_LOCK_TABLE }}
```

### ✅ Result:
GitHub Actions can deploy infrastructure without hardcoded credentials!

---

## Next: Test It

1. ✅ Run bootstrap
2. ✅ Add 4 GitHub Secrets
3. ✅ Create a PR with Terraform changes
4. ✅ CI/CD will run `terraform plan`
5. ✅ Review plan output
6. ✅ Merge to main and watch `terraform apply` run

Done! 🚀
