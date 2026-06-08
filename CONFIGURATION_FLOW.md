# Configuration Flow Diagram

## How Configuration Flows Through the System

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. LOCAL DEVELOPMENT                                             │
│                                                                   │
│ terraform/terraform.tfvars (your local values)                   │
│    ↓                                                              │
│ terraform init (reads tfvars)                                    │
│    ↓                                                              │
│ terraform plan/apply (uses variables)                            │
└─────────────────────────────────────────────────────────────────┘
                           ↓
                      (git push)
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. GITHUB CI/CD                                                  │
│                                                                  │
│ .github/workflows/ci-cd-tf-plan.yml                              │
│    ↓                                                              │
│ Uses GitHub Secrets:                                             │
│   • AWS_ROLE_TO_ASSUME                                           │
│   • AWS_REGION                                                   │
│   • TF_STATE_BUCKET                                              │
│   • TF_LOCK_TABLE                                                │
│    ↓                                                              │
│ terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}"
│    ↓                                                              │
│ terraform plan                                                   │
│    ↓                                                              │
│ Posts plan as PR comment                                         │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration Sources

### Local Development
- **Source**: `terraform/terraform.tfvars`
- **Used by**: `terraform init`, `terraform plan`, `terraform apply`
- **Scope**: Your local machine only

### GitHub Actions
- **Source**: GitHub Repository Secrets
- **Used by**: Workflow files in `.github/workflows/`
- **Scope**: All CI/CD operations (plan, apply, etc.)

### Variables Definition
- **Source**: `terraform/variables-backend.tf`
- **Used by**: Terraform validation and schema checking
- **Scope**: Applies to all tfvars values

---

## Key Configuration Values

| Name | Location | Used By | Example |
|------|----------|---------|---------|
| `project_name` | `terraform.tfvars` | Resource naming | `purely` |
| `environment` | `terraform.tfvars` | Resource naming, tags | `production` |
| `aws_region` | GitHub Secret `AWS_REGION` | AWS API calls | `us-east-1` |
| `tf_state_bucket` | GitHub Secret `TF_STATE_BUCKET` | Backend init | `purely-terraform-state` |
| `tf_lock_table` | GitHub Secret `TF_LOCK_TABLE` | State locking | `purely-terraform-locks` |
| `github_actions_role_name` | Hardcoded in IAM | GitHub OIDC | `github-actions-terraform-role` |
| `AWS_ROLE_TO_ASSUME` | GitHub Secret | AWS authentication | `arn:aws:iam::...:role/...` |

---

## Customization by Environment

### Development
**File**: `terraform.tfvars.dev` (or use `-var-file` flag)
```hcl
project_name     = "purely"
environment      = "dev"
aws_region       = "us-east-1"
tf_state_bucket  = "purely-terraform-state-dev"
tf_lock_table    = "purely-terraform-locks-dev"
```

### Production
**File**: `terraform.tfvars.prod`
```hcl
project_name     = "purely"
environment      = "prod"
aws_region       = "us-east-1"
tf_state_bucket  = "purely-terraform-state-prod"
tf_lock_table    = "purely-terraform-locks-prod"
```

---

## How to Add a New Configuration Variable

1. **Define in Terraform**
   ```hcl
   # terraform/variables-backend.tf
   variable "new_variable" {
     description = "Description"
     type        = string
     default     = "value"
   }
   ```

2. **Add to tfvars**
   ```hcl
   # terraform/terraform.tfvars
   new_variable = "your_value"
   ```

3. **Use in code**
   ```hcl
   # terraform/some-file.tf
   resource "aws_resource" "name" {
     property = var.new_variable
   }
   ```

4. **For GitHub Secrets (if sensitive)**
   ```yaml
   # .github/workflows/ci-cd-tf-plan.yml
   env:
     NEW_VARIABLE: ${{ secrets.NEW_VARIABLE }}
   ```

---

## Troubleshooting Configuration Issues

### "variable not defined"
Check:
- [ ] Variable is defined in `variables-backend.tf`
- [ ] Value is set in `terraform.tfvars`
- [ ] No typos in variable name

### "backend initialization failed"
Check:
- [ ] GitHub Secrets are set correctly
- [ ] S3 bucket exists (created by bootstrap)
- [ ] DynamoDB table exists (created by bootstrap)

### "terraform plan uses wrong values"
Check:
- [ ] Using correct tfvars file
- [ ] Variables are passed with `-var-file=` or set as environment
- [ ] No conflicting variables in environment

---

## Next Steps

1. ✅ Review `terraform/terraform.tfvars`
2. ✅ Run `./scripts/bootstrap-terraform.sh`
3. ✅ Add GitHub Secrets
4. ✅ Run `terraform init` in `terraform/` directory
5. ✅ Verify with `terraform plan`
