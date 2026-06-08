# CI/CD Workflows - Targeted Path Filtering

## Overview

All CI/CD workflows now use intelligent path filtering to prevent unnecessary builds and deployments:

```
┌─────────────────────────────────────────────────────────────┐
│ Terraform Changes                                            │
├─────────────────────────────────────────────────────────────┤
│ terraform/** OR bootstrap/** OR .github/workflows/ci-cd-tf-*
│          ↓                                                    │
│ Triggers: ci-cd-tf-plan.yml                                 │
│           ci-cd-tf-apply.yml (requires plan success + approval)
│                                                              │
│ Does NOT trigger: Any microservice workflows                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Auth Service Changes                                         │
├─────────────────────────────────────────────────────────────┤
│ microservice-backend/auth-service/** OR                     │
│ helm-charts/auth-service/** OR                              │
│ .github/workflows/ci-cd-auth.yml                            │
│          ↓                                                    │
│ Triggers: ci-cd-auth.yml ONLY                               │
│                                                              │
│ Does NOT trigger if: terraform OR other services change    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Similar for: Cart, Category, Gateway, Order, Product,       │
│              User, Notification, Web, Registry, Ingress     │
└─────────────────────────────────────────────────────────────┘
```

---

## Workflow Triggers

### Terraform Workflows

#### `ci-cd-tf-plan.yml`
- **Triggered on:**
  - PR with changes in `terraform/**` OR `bootstrap/**` OR terraform workflow files
  - Push to main with terraform changes

- **Path filter:**
  ```yaml
  paths:
    - 'terraform/**'
    - 'bootstrap/**'
    - '.github/workflows/ci-cd-tf-plan.yml'
  ```

- **What it does:**
  - Runs terraform plan on PR
  - Posts plan output as PR comment
  - Saves plan artifact

#### `ci-cd-tf-apply.yml`
- **Triggered on:**
  - Push to main only (NOT on PR)
  - Changes in `terraform/**` OR `bootstrap/**` OR terraform workflow files

- **Path filter:**
  ```yaml
  paths:
    - 'terraform/**'
    - 'bootstrap/**'
    - '.github/workflows/ci-cd-tf-apply.yml'
  ```

- **Two jobs with dependency:**
  1. **`terraform-plan`** (runs first)
     - Validates terraform
     - Creates plan artifact
  
  2. **`terraform-apply`** (runs after plan succeeds)
     - Requires: Production environment approval
     - Downloads plan artifact
     - Applies terraform
     - Exports outputs

---

### Microservice Workflows

Each microservice has its own workflow that triggers ONLY for changes in its folder:

#### `ci-cd-auth.yml`
```yaml
paths:
  - 'microservice-backend/auth-service/**'
  - 'helm-charts/auth-service/**'
  - '.github/workflows/ci-cd-auth.yml'
paths-ignore:
  - 'terraform/**'
  - 'bootstrap/**'
  - '.github/workflows/ci-cd-tf-*.yml'
  - '**.md'
```

#### `ci-cd-cart.yml`
```yaml
paths:
  - 'microservice-backend/cart-service/**'
  - 'helm-charts/cart-service/**'
  - '.github/workflows/ci-cd-cart.yml'
paths-ignore:
  - [same as above]
```

#### Same pattern for:
- `ci-cd-category.yml`
- `ci-cd-gateway.yml`
- `ci-cd-order.yml`
- `ci-cd-product.yml`
- `ci-cd-user.yml`
- `ci-cd-notification.yml`
- `ci-cd-registry.yml`

#### `ci-cd-web.yml`
```yaml
paths:
  - 'frontend/**'
  - 'helm-charts/web-app/**'
  - '.github/workflows/ci-cd-web.yml'
paths-ignore:
  - [same as above]
```

#### `ci-cd-ingress.yml`
```yaml
paths:
  - 'helm-charts/ingress-alb/**'
  - '.github/workflows/ci-cd-ingress.yml'
paths-ignore:
  - [same as above]
```

---

## Path Filter Logic

### `paths` (Include)
Workflow only runs if commit touches ANY of these paths:
```yaml
paths:
  - 'microservice-backend/auth-service/**'   # Auth service code
  - 'helm-charts/auth-service/**'             # Auth helm chart
  - '.github/workflows/ci-cd-auth.yml'        # Workflow file itself
```

### `paths-ignore` (Exclude)
Workflow is skipped if commit touches ONLY these paths:
```yaml
paths-ignore:
  - 'terraform/**'                    # Don't trigger on terraform changes
  - 'bootstrap/**'                    # Don't trigger on bootstrap changes
  - '.github/workflows/ci-cd-tf-*.yml' # Don't trigger on terraform CI/CD
  - '**.md'                            # Don't trigger on markdown (docs)
```

---

## Workflow Execution Examples

### Example 1: Auth Service Change
```bash
git commit -m "fix: auth service login bug"
git push origin main

# Changes: microservice-backend/auth-service/src/...
# Triggered: ✅ ci-cd-auth.yml
# Not triggered: ❌ ci-cd-tf-apply.yml, ci-cd-cart.yml, ci-cd-user.yml
```

### Example 2: Terraform Change
```bash
git commit -m "feat: add new EKS node group"
git push origin main

# Changes: terraform/eks-node-groups.tf
# Triggered: ✅ ci-cd-tf-plan.yml (on PR), ci-cd-tf-apply.yml (on main)
# Not triggered: ❌ Any microservice workflow
```

### Example 3: Multiple Services
```bash
git commit -m "update: multiple services for feature X"
git push origin main

# Changes: 
#   - microservice-backend/auth-service/...
#   - microservice-backend/order-service/...
#
# Triggered:
#   ✅ ci-cd-auth.yml
#   ✅ ci-cd-order.yml
#
# Not triggered:
#   ❌ ci-cd-cart.yml, ci-cd-user.yml (no changes in these)
```

### Example 4: README Update
```bash
git commit -m "docs: update README"
git push origin main

# Changes: README.md
# Triggered: ❌ NOTHING (all workflows ignore **.md)
```

---

## Terraform Plan & Apply Flow

### On Pull Request:
```
1. PR created with terraform changes
   ↓
2. ci-cd-tf-plan.yml triggers automatically
   ↓
3. Terraform plan runs
   ↓
4. Plan posted as PR comment
   ↓
5. Reviewers check plan output
   ↓
6. Approve & merge PR
```

### On Merge to Main:
```
1. PR merged (terraform changes)
   ↓
2. ci-cd-tf-apply.yml triggers
   ↓
3. terraform-plan job runs
   ├─ Validates terraform
   ├─ Creates plan artifact
   └─ Succeeds ✓
   ↓
4. terraform-apply job waits for approval
   ├─ GitHub shows "Awaiting approval" status
   ├─ Authorized reviewer approves in GitHub UI
   └─ Or approval times out (24 hours default)
   ↓
5. terraform-apply job runs after approval
   ├─ Downloads plan artifact
   ├─ Runs terraform apply
   ├─ Exports outputs
   └─ Resources created/updated
```

---

## Key Configuration Points

| Aspect | Before | After |
|--------|--------|-------|
| Terraform triggers | Only on `terraform/**` | Also on `bootstrap/**` & terraform workflow files |
| Microservice triggers | All services on any file | Each service only on its own folder |
| Terraform apply | Auto-approve risk | Requires manual approval |
| Plan vs Apply | Same job | Separate jobs with dependency |
| Markdown changes | Trigger builds | Ignored (skip unnecessary runs) |

---

## Benefits

✅ **Targeted Execution** - Only relevant workflows run
✅ **Cost Savings** - Fewer unnecessary builds/deployments
✅ **Faster Feedback** - Parallel service builds (if changes touch multiple services)
✅ **Safety** - Terraform apply requires approval
✅ **Plan First** - Can review plan before apply
✅ **Audit Trail** - Every apply is approved and logged
✅ **No Terraform Interference** - Microservices don't trigger on IaC changes

---

## Verification

### Check Workflow Triggers
1. Go to GitHub: **Actions** tab
2. Click each workflow
3. Check "Workflow file" in details

### Manual Workflow Trigger
```bash
# Trigger on PR
git push origin feature-branch
# (Create PR on GitHub)

# Trigger on main
git push origin main
```

### View Workflow Runs
1. Go to GitHub: **Actions** tab
2. Click workflow name
3. View run history and logs

---

## Troubleshooting

### Workflow Didn't Trigger

**Problem:** I pushed changes but workflow didn't run

**Solutions:**
1. Check path filters match your changes:
   ```bash
   git diff HEAD~1 --name-only
   # Compare output with paths: in workflow
   ```

2. Verify path format:
   - `**` = any subdirectory
   - `*.yml` = any .yml file
   - `folder/**` = entire folder recursively

3. Check `paths-ignore`:
   - If changes match `paths-ignore`, workflow is skipped
   - This is by design (e.g., markdown changes)

### Workflow Triggered Unexpectedly

**Problem:** Workflow ran but I didn't expect it

**Solutions:**
1. Check if multiple services were affected:
   ```bash
   git diff HEAD~1 --name-only | grep microservice-backend
   ```

2. Verify paths in workflow file:
   - Are the paths too broad?
   - Should we add more to `paths-ignore`?

### Terraform Apply Not Triggering

**Problem:** I merged to main but terraform apply didn't run

**Solutions:**
1. Verify it's the main branch
2. Verify changes touched `terraform/**` or `bootstrap/**`
3. Check if ci-cd-tf-plan.yml succeeded first
4. Approval may be pending - check "Required status checks"

---

## Next Steps

1. ✅ Push changes to a feature branch
2. ✅ Create PR and verify terraform plan runs
3. ✅ Review plan output in PR comment
4. ✅ Merge PR
5. ✅ Watch main branch: verify terraform apply runs
6. ✅ Approve in GitHub when prompted
7. ✅ Resources are deployed!

All workflows now have proper path filtering and dependencies! 🎯
