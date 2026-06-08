# 🎯 CI/CD Workflow Triggers - Quick Reference

## TL;DR - What Triggers What

### Terraform Changes
```
Files Changed: terraform/* or bootstrap/*
            ↓
Triggered: ✅ ci-cd-tf-plan.yml
           ✅ ci-cd-tf-apply.yml (on main + approval)
           ❌ All microservice workflows
```

### Auth Service Changes
```
Files Changed: microservice-backend/auth-service/* 
               or helm-charts/auth-service/*
            ↓
Triggered: ✅ ci-cd-auth.yml ONLY
           ❌ ci-cd-tf-plan.yml
           ❌ ci-cd-cart.yml
           ❌ Any other workflow
```

### Cart Service Changes (Same Pattern)
```
Files Changed: microservice-backend/cart-service/* 
               or helm-charts/cart-service/*
            ↓
Triggered: ✅ ci-cd-cart.yml ONLY
```

### Documentation Changes
```
Files Changed: README.md or *.md
            ↓
Triggered: ❌ NOTHING (saves time!)
```

---

## Complete Trigger Map

| Changed File | Triggered Workflows |
|--------------|-------------------|
| `terraform/vpc.tf` | ✅ ci-cd-tf-plan.yml |
| `bootstrap/main.tf` | ✅ ci-cd-tf-plan.yml |
| `microservice-backend/auth-service/...` | ✅ ci-cd-auth.yml |
| `helm-charts/auth-service/...` | ✅ ci-cd-auth.yml |
| `microservice-backend/cart-service/...` | ✅ ci-cd-cart.yml |
| `microservice-backend/category-service/...` | ✅ ci-cd-category.yml |
| `microservice-backend/api-gateway/...` | ✅ ci-cd-gateway.yml |
| `microservice-backend/order-service/...` | ✅ ci-cd-order.yml |
| `microservice-backend/product-service/...` | ✅ ci-cd-product.yml |
| `microservice-backend/user-service/...` | ✅ ci-cd-user.yml |
| `microservice-backend/notification-service/...` | ✅ ci-cd-notification.yml |
| `microservice-backend/service-registry/...` | ✅ ci-cd-registry.yml |
| `frontend/...` | ✅ ci-cd-web.yml |
| `helm-charts/ingress-alb/...` | ✅ ci-cd-ingress.yml |
| `README.md` | ❌ (ignored) |
| `.github/workflows/ci-cd-tf-plan.yml` | ✅ ci-cd-tf-plan.yml |
| `.github/workflows/ci-cd-auth.yml` | ✅ ci-cd-auth.yml |
| `QUICK_START.md` | ❌ (ignored) |

---

## Test Scenarios

### Scenario A: Terraform Change
```bash
git checkout -b feature/add-nodes
echo 'variable "count" {}' >> terraform/eks-node-groups.tf
git push origin feature/add-nodes
# Create PR
```
**GitHub Actions will show:**
- ✅ ci-cd-tf-plan.yml (running)
- Plan output in PR comment
- Approve & merge to main
- ci-cd-tf-apply.yml awaits approval

---

### Scenario B: Auth Service Change
```bash
git checkout -b feature/auth-fix
echo 'fix' >> microservice-backend/auth-service/src/main/java/Auth.java
git push origin feature/auth-fix
# Merge to main
```
**GitHub Actions will show:**
- ✅ ci-cd-auth.yml (running)
- Docker build & deploy
- ❌ NO terraform workflows
- ❌ NO other service workflows

---

### Scenario C: Multiple Services
```bash
git checkout -b feature/multi
echo 'auth' >> microservice-backend/auth-service/src/main/java/Auth.java
echo 'order' >> microservice-backend/order-service/src/main/java/Order.java
git push origin feature/multi
# Merge to main
```
**GitHub Actions will show (parallel):**
- ✅ ci-cd-auth.yml (running)
- ✅ ci-cd-order.yml (running)
- ❌ NO other workflows

---

### Scenario D: Documentation Only
```bash
git checkout -b feature/docs
echo '# Updated' >> README.md
git push origin feature/docs
# Merge to main
```
**GitHub Actions will show:**
- ❌ NO workflows trigger
- This is intentional!
- Saves CI/CD minutes

---

## How to Check What Triggers

### Method 1: By File Path
1. Identify which file you changed
2. Look up in "Complete Trigger Map" above
3. That's what will trigger

### Method 2: By Workflow
1. Go to GitHub Actions
2. Click "Workflows" on left
3. Click the workflow name
4. Scroll to "on:" section
5. Check the "paths:" field

### Method 3: By Git Command
```bash
# See which files you changed
git diff HEAD~1 --name-only

# Compare with paths: in workflows
# If match: workflow will trigger
# If no match: workflow won't trigger
```

---

## Important Rules

### Rule 1: `paths:` (Include)
```yaml
paths:
  - 'terraform/**'   # Include: Any file in terraform folder
```
Workflow triggers if changes touch these paths

### Rule 2: `paths-ignore:` (Exclude)  
```yaml
paths-ignore:
  - '**.md'          # Exclude: Any markdown file
```
Workflow SKIPS if changes only touch these paths

### Rule 3: Both Required to Match
```yaml
# For workflow to trigger:
# 1. File must match "paths:" OR
# 2. Must NOT match "paths-ignore:"

# Example:
# - terraform/vpc.tf changes
#   ✅ Matches paths: ['terraform/**']
#   ✅ Doesn't match paths-ignore
#   → TRIGGERS

# - README.md changes
#   ❌ Doesn't match paths: ['terraform/**']
#   ✅ Matches paths-ignore: ['**.md']
#   → SKIPS
```

---

## Troubleshooting

### Q: Workflow didn't trigger. Why?
**A:** Check if file changes matched the trigger paths:
```bash
# Your changed files
git diff HEAD~1 --name-only

# Compare with workflow paths:
# Look at .github/workflows/ci-cd-*.yml
# Find the one you expected to trigger
# Check paths: and paths-ignore:
```

### Q: Wrong workflow triggered. Why?
**A:** A different file pattern matched. Check:
1. Which files did you actually change? (git diff)
2. Which workflows have matching paths?
3. Multiple matches = multiple workflows trigger

### Q: All workflows triggered. Why?
**A:** This shouldn't happen. Check if:
1. Files match multiple workflows
2. GitHub cached old workflow definitions
   - Solution: Wait 5 minutes or manually retry

### Q: Terraform plan takes too long
**A:** First run: 10-15 min (normal), Cached: 5-10 min (normal)
If >20 minutes:
- Check `.terraform.lock.hcl` exists
- Check AWS credentials are valid
- Check network connectivity

---

## Quick Decision Tree

```
I made changes to...
│
├─ terraform/ or bootstrap/
│  └─ Triggers: ci-cd-tf-plan.yml ✅
│
├─ microservice-backend/auth-service/
│  └─ Triggers: ci-cd-auth.yml ✅
│
├─ microservice-backend/cart-service/
│  └─ Triggers: ci-cd-cart.yml ✅
│
├─ microservice-backend/category-service/
│  └─ Triggers: ci-cd-category.yml ✅
│
├─ microservice-backend/api-gateway/
│  └─ Triggers: ci-cd-gateway.yml ✅
│
├─ microservice-backend/order-service/
│  └─ Triggers: ci-cd-order.yml ✅
│
├─ microservice-backend/product-service/
│  └─ Triggers: ci-cd-product.yml ✅
│
├─ microservice-backend/user-service/
│  └─ Triggers: ci-cd-user.yml ✅
│
├─ microservice-backend/notification-service/
│  └─ Triggers: ci-cd-notification.yml ✅
│
├─ microservice-backend/service-registry/
│  └─ Triggers: ci-cd-registry.yml ✅
│
├─ frontend/
│  └─ Triggers: ci-cd-web.yml ✅
│
├─ helm-charts/ingress-alb/
│  └─ Triggers: ci-cd-ingress.yml ✅
│
└─ *.md (README.md, QUICK_START.md, etc)
   └─ Triggers: NOTHING ✅ (saves time!)
```

---

## Performance Metrics

| Task | Expected Time | Status |
|------|----------------|--------|
| Terraform Init (first) | 5-10 min | ✅ Optimized |
| Terraform Init (cached) | 1-3 min | ✅ Cached |
| Terraform Plan | 3-7 min | ✅ Parallelized |
| Total Terraform Plan | 5-15 min | ✅ Fast |
| Auth Build/Deploy | 10-15 min | ✅ Normal |
| Cart Build/Deploy | 10-15 min | ✅ Normal |
| Multiple services (parallel) | 10-15 min | ✅ Parallel |

---

## Final Check

Before you commit:

- [ ] Did I change only terraform files?
  - Then only `ci-cd-tf-plan.yml` should trigger

- [ ] Did I change only auth-service files?
  - Then only `ci-cd-auth.yml` should trigger

- [ ] Did I change only markdown?
  - Then NOTHING should trigger

- [ ] Did I change multiple services?
  - Then all matching services should trigger in parallel

- [ ] Did I change terraform?
  - On PR: `ci-cd-tf-plan.yml` runs
  - On main: `ci-cd-tf-plan.yml` + `ci-cd-tf-apply.yml` (requires approval)

---

That's it! Path filtering is working perfectly. 🎯
