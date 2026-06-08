# CI/CD Path Filtering - Final Configuration & Troubleshooting

## ✅ CURRENT CONFIGURATION

### Terraform Workflows - STRICT PATH FILTERING

#### `ci-cd-tf-plan.yml` Triggers When:
```yaml
on:
  pull_request:
    paths:
      - 'terraform/**'              # Any file in terraform folder
      - 'bootstrap/**'              # Any file in bootstrap folder
      - '.github/workflows/ci-cd-tf-plan.yml'  # This file itself
  push:
    branches: [main]
    paths: [same as above]
```

**When It Triggers:**
- ✅ PR with changes to `terraform/eks-cluster.tf`
- ✅ PR with changes to `bootstrap/main.tf`
- ✅ Push to main with terraform changes
- ✅ PR with changes to `.github/workflows/ci-cd-tf-plan.yml`

**When It Does NOT Trigger:**
- ❌ Changes to `microservice-backend/auth-service/**`
- ❌ Changes to `frontend/**`
- ❌ Changes to `README.md`
- ❌ Changes to other service workflows

#### `ci-cd-tf-apply.yml` Triggers When:
```yaml
on:
  push:
    branches: [main]  # ONLY MAIN (NOT PR)
    paths: [same as tf-plan]
```

**Behavior:**
- ✅ Job 1: `terraform-plan-job` (runs automatically)
- ⏸️ Job 2: `terraform-apply-job` (waits for approval)
- ✅ Only runs after plan succeeds
- ✅ Requires manual approval in GitHub UI

---

### Microservice Workflows - ISOLATED PATHS

#### `ci-cd-auth.yml` Triggers When:
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'microservice-backend/auth-service/**'
      - 'helm-charts/auth-service/**'
      - '.github/workflows/ci-cd-auth.yml'
    paths-ignore:
      - 'terraform/**'           # Ignore terraform changes
      - 'bootstrap/**'           # Ignore bootstrap changes
      - '.github/workflows/ci-cd-tf-*.yml'  # Ignore terraform workflows
      - '**.md'                  # Ignore markdown files
```

**When It Triggers:**
- ✅ Push to main with changes to `microservice-backend/auth-service/src/...`
- ✅ Push to main with changes to `helm-charts/auth-service/Chart.yaml`
- ✅ Push to main with changes to `.github/workflows/ci-cd-auth.yml`

**When It Does NOT Trigger:**
- ❌ `terraform/` changes (explicitly ignored)
- ❌ `microservice-backend/cart-service/` changes (different service)
- ❌ `microservice-backend/order-service/` changes (different service)
- ❌ `README.md` changes (markdown ignored)
- ❌ `.github/workflows/ci-cd-tf-plan.yml` changes (terraform workflow ignored)

#### Same Pattern For All Services:
- `ci-cd-cart.yml` → `microservice-backend/cart-service/**`
- `ci-cd-category.yml` → `microservice-backend/category-service/**`
- `ci-cd-gateway.yml` → `microservice-backend/api-gateway/**`
- `ci-cd-order.yml` → `microservice-backend/order-service/**`
- `ci-cd-product.yml` → `microservice-backend/product-service/**`
- `ci-cd-user.yml` → `microservice-backend/user-service/**`
- `ci-cd-notification.yml` → `microservice-backend/notification-service/**`
- `ci-cd-registry.yml` → `microservice-backend/service-registry/**`
- `ci-cd-web.yml` → `frontend/**`
- `ci-cd-ingress.yml` → `helm-charts/ingress-alb/**`

---

## 🧪 TESTING THE CONFIGURATION

### Test 1: Only Terraform Workflow Should Trigger
```bash
# Create branch
git checkout -b test/terraform-change

# Edit terraform file
echo 'variable "test" {}' >> terraform/test.tf

# Push
git push origin test/terraform-change

# Create PR on GitHub
```

**Expected Result:**
```
✅ Actions Tab Shows:
   └─ ci-cd-tf-plan.yml (Running)

❌ Should NOT show:
   └─ ci-cd-auth.yml
   └─ ci-cd-cart.yml
   └─ ci-cd-web.yml
   └─ Any other microservice workflow
```

**Why:** Changes only touch `terraform/**`

---

### Test 2: Only Auth Workflow Should Trigger
```bash
# Create branch
git checkout -b test/auth-change

# Edit auth service
echo "// test" >> microservice-backend/auth-service/src/main/java/com/example/Auth.java

# Push to main
git push origin test/auth-change
# Then merge to main
```

**Expected Result:**
```
✅ Actions Tab Shows:
   └─ ci-cd-auth.yml (Running)

❌ Should NOT show:
   └─ ci-cd-tf-plan.yml
   └─ ci-cd-cart.yml
   └─ ci-cd-order.yml
   └─ ci-cd-web.yml
   └─ Any terraform workflow
```

**Why:** Changes only touch `microservice-backend/auth-service/**`

---

### Test 3: Multiple Services Should Trigger In Parallel
```bash
# Create branch
git checkout -b test/multi-service

# Edit auth service
echo "// auth" >> microservice-backend/auth-service/src/main/java/com/example/Auth.java

# Edit order service
echo "// order" >> microservice-backend/order-service/src/main/java/com/example/Order.java

# Push to main
git push origin test/multi-service
# Then merge to main
```

**Expected Result:**
```
✅ Actions Tab Shows (both running in parallel):
   ├─ ci-cd-auth.yml (Running)
   └─ ci-cd-order.yml (Running)

❌ Should NOT show:
   └─ ci-cd-tf-plan.yml
   └─ ci-cd-cart.yml
   └─ ci-cd-user.yml
   └─ Any other service
```

**Why:** Changes touch both `microservice-backend/auth-service/**` and `microservice-backend/order-service/**`

---

### Test 4: Terraform Workflow Should NOT Trigger On Markdown
```bash
# Create branch
git checkout -b test/docs-change

# Edit documentation
echo "# Updated" >> README.md

# Push to main
git push origin test/docs-change
# Then merge to main
```

**Expected Result:**
```
❌ Actions Tab Should Show:
   (NO WORKFLOWS TRIGGER)

Why: All workflows have paths-ignore: ['**.md']
```

This saves CI/CD minutes by ignoring documentation changes!

---

### Test 5: Terraform Apply Should Wait For Approval
```bash
# Create branch
git checkout -b test/tf-apply

# Edit terraform
echo 'variable "new" {}' >> terraform/test.tf

# Create PR and merge
git push origin test/tf-apply
# Merge to main
```

**Expected Result:**
```
✅ Actions Tab Shows:
   ├─ ci-cd-tf-apply.yml (Running)
   │  ├─ terraform-plan-job: ✅ Succeeded
   │  └─ terraform-apply-job: ⏸️ Waiting for approval

🎯 Then in GitHub:
   ├─ Go to Actions tab
   ├─ Click terraform-apply-job
   ├─ Click "Review Deployments" button
   ├─ Select "Approve"
   └─ terraform-apply starts

✅ Once approved:
   └─ terraform-apply-job: ✅ Apply complete
```

---

## 🔍 TROUBLESHOOTING

### Problem: All Workflows Trigger (Not Just The One I Changed)

**Cause:** This shouldn't happen with correct path filtering

**Solution:**
1. Check GitHub Actions tab for which workflows actually ran
2. Verify the paths in the workflow match your changes
3. Verify `paths-ignore` is properly excluding unrelated changes

---

### Problem: Workflow Should Trigger But Doesn't

**Checklist:**

1. **Check you pushed to correct branch:**
   ```bash
   git branch  # Should show main or feature branch
   ```

2. **Check the changed files match paths:**
   ```bash
   git diff HEAD~1 --name-only
   # Compare with "paths:" in the workflow
   ```

3. **Verify paths syntax is correct:**
   ```yaml
   paths:
     - 'terraform/**'      # ✅ Correct (any file in terraform folder)
     - 'terraform/*'       # ❌ Wrong (only direct children)
     - 'terraform/'        # ❌ Wrong (directory itself, not files)
   ```

4. **Check for paths-ignore blocking it:**
   ```yaml
   paths-ignore:
     - '**.md'            # If your file matches this, it won't trigger
   ```

---

### Problem: Terraform Plan Takes Too Long

**Solution:**
Provider caching should speed it up. Check:

1. **First run:** Should take 10-15 minutes
2. **Subsequent runs:** Should take 5-10 minutes (cached)
3. **If still slow:**
   ```bash
   # Check terraform lock file exists
   ls -la terraform/.terraform.lock.hcl
   
   # If missing, workflows will re-download providers
   ```

---

### Problem: Terraform Apply Doesn't Require Approval

**Solution:**
Check that the environment is configured:

```yaml
terraform-apply-job:
  needs: terraform-plan-job
  environment:
    name: production
    approval: required  # This must be present
```

Also verify GitHub environment protection:
- Go to: Settings → Environments → production
- Set: "Required reviewers"

---

## 📊 Path Filtering Reference Table

| Change Type | File Changed | Triggers |
|-------------|-------------|----------|
| Terraform | `terraform/vpc.tf` | ✅ `ci-cd-tf-plan.yml` |
| Terraform | `bootstrap/main.tf` | ✅ `ci-cd-tf-plan.yml` |
| Auth Code | `microservice-backend/auth-service/...` | ✅ `ci-cd-auth.yml` |
| Auth Helm | `helm-charts/auth-service/...` | ✅ `ci-cd-auth.yml` |
| Cart Code | `microservice-backend/cart-service/...` | ✅ `ci-cd-cart.yml` |
| Order Code | `microservice-backend/order-service/...` | ✅ `ci-cd-order.yml` |
| Frontend | `frontend/...` | ✅ `ci-cd-web.yml` |
| Documentation | `README.md` | ❌ (ignored) |
| Terraform Workflow | `.github/workflows/ci-cd-tf-plan.yml` | ✅ `ci-cd-tf-plan.yml` |
| Auth Workflow | `.github/workflows/ci-cd-auth.yml` | ✅ `ci-cd-auth.yml` |

---

## ✅ VERIFICATION CHECKLIST

- [ ] Terraform workflow only triggers on terraform changes
- [ ] Auth workflow only triggers on auth-service changes
- [ ] Cart workflow only triggers on cart-service changes
- [ ] Multiple services can trigger in parallel
- [ ] Markdown changes don't trigger anything
- [ ] Terraform plan completes in <20 minutes
- [ ] Terraform apply requires approval
- [ ] No cross-service interference

---

## 🚀 QUICK SUMMARY

**The Setup:**
- Terraform changes → `ci-cd-tf-plan.yml` (PR) + `ci-cd-tf-apply.yml` (main + approval)
- Auth service changes → `ci-cd-auth.yml` only
- Cart service changes → `ci-cd-cart.yml` only
- Each service completely isolated
- No terraform interference with microservices
- No microservice interference with terraform

**The Benefit:**
- ✅ Fast CI/CD (only relevant workflows run)
- ✅ Lower costs (fewer unnecessary builds)
- ✅ Production safety (terraform requires approval)
- ✅ Service isolation (no dependencies)
- ✅ Parallel execution (multiple services together)

**Test It:**
- Make terraform change → Only terraform workflow runs ✅
- Make auth change → Only auth workflow runs ✅
- Make markdown change → Nothing runs (saves time!) ✅

All done! Path filtering is now production-ready. 🎯
