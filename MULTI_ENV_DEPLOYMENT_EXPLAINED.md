# =============================================================================
# MULTI-ENVIRONMENT DEPLOYMENT ARCHITECTURE EXPLAINED
# =============================================================================
# Understanding Namespaces, Helm, and Enterprise CI/CD
# =============================================================================

## 📚 Table of Contents
1. [Why Kubernetes Namespaces?](#why-namespaces)
2. [How Helm Uses Environment Files](#helm-environment-files)
3. [When Helm Commands Run](#when-helm-runs)
4. [Flexible CI/CD for Multiple Environments](#flexible-cicd)
5. [Complete Deployment Flow](#complete-flow)

---

## 🏗️ Why Kubernetes Namespaces? <a name="why-namespaces"></a>

### The Problem Without Namespaces

Imagine you have ONE Kubernetes cluster and want to run:
- Development version of your app (for developers to test)
- QA version (for testers)
- Production version (for real users)

**Without namespaces, you'd have conflicts:**
```
❌ auth-service (dev version)     - NAME CONFLICT!
❌ auth-service (qa version)      - NAME CONFLICT!
❌ auth-service (prod version)    - NAME CONFLICT!
```

### The Solution: Namespaces

Namespaces are like **virtual clusters within a cluster**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                      KUBERNETES CLUSTER (EKS)                        │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │   NAMESPACE:    │  │   NAMESPACE:    │  │   NAMESPACE:    │     │
│  │      dev        │  │       qa        │  │      prod       │     │
│  │                 │  │                 │  │                 │     │
│  │ • auth-service  │  │ • auth-service  │  │ • auth-service  │     │
│  │ • api-gateway   │  │ • api-gateway   │  │ • api-gateway   │     │
│  │ • product-svc   │  │ • product-svc   │  │ • product-svc   │     │
│  │   ...           │  │   ...           │  │   ...           │     │
│  │                 │  │                 │  │                 │     │
│  │ 1 replica each  │  │ 2 replicas each │  │ 3+ replicas     │     │
│  │ 256Mi memory    │  │ 512Mi memory    │  │ 1Gi memory      │     │
│  │ DEBUG logs      │  │ INFO logs       │  │ WARN logs       │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Why Enterprise Apps Use Namespaces

| Benefit | Explanation |
|---------|-------------|
| **Isolation** | Dev bugs can't affect production |
| **Resource Quotas** | Limit dev to 10 CPUs, prod gets 100 CPUs |
| **Network Policies** | Prevent dev from talking to prod databases |
| **RBAC** | Developers can only access `dev` namespace |
| **Cost Tracking** | See how much each environment costs |
| **Same Names** | `auth-service` can exist in all 3 namespaces |

### Namespace Commands

```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace qa
kubectl create namespace prod

# List all namespaces
kubectl get namespaces

# See what's in each namespace
kubectl get pods -n dev
kubectl get pods -n qa
kubectl get pods -n prod

# Switch default namespace
kubectl config set-context --current --namespace=prod
```

---

## 📁 How Helm Uses Environment Files <a name="helm-environment-files"></a>

### The Helm Chart Structure

```
helm-charts/
├── auth-service/                    # The CHART (template)
│   ├── Chart.yaml                   # Chart metadata
│   ├── values.yaml                  # DEFAULT values (PRODUCTION-ready)
│   └── templates/                   # Kubernetes manifest templates
│       ├── deployment.yaml
│       ├── service.yaml
│       └── hpa.yaml
│
└── environments/                    # OVERRIDES per environment
    ├── dev/
    │   └── auth-service.yaml        # Dev-specific values
    ├── qa/
    │   └── auth-service.yaml        # QA-specific values
    └── prod/
        └── auth-service.yaml        # Prod-specific (if needed)
```

### How Values Cascade (Priority Order)

```
LOWEST PRIORITY                                    HIGHEST PRIORITY
      │                                                  │
      ▼                                                  ▼
┌─────────────┐    ┌────────────────────┐    ┌────────────────────┐
│ values.yaml │ ─→ │ environments/      │ ─→ │ --set on command   │
│ (defaults)  │    │ dev/auth-svc.yaml  │    │ line               │
│             │    │ (file override)    │    │ (runtime override) │
└─────────────┘    └────────────────────┘    └────────────────────┘
```

### Example: How It Works

**Base values.yaml (Production defaults):**
```yaml
# helm-charts/auth-service/values.yaml
auth:
  replicas: 3                    # Production: 3 replicas
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  autoscaling:
    enabled: true                # Production: HPA enabled
    minReplicas: 3
    maxReplicas: 10
config:
  LOG_LEVEL: WARN               # Production: minimal logs
```

**Dev override file:**
```yaml
# helm-charts/environments/dev/auth-service.yaml
auth:
  replicas: 1                    # Dev: only 1 replica
  resources:
    requests:
      cpu: 100m                  # Dev: minimal resources
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  autoscaling:
    enabled: false               # Dev: no HPA
config:
  LOG_LEVEL: DEBUG              # Dev: verbose logs
```

### Helm Commands for Each Environment

```bash
# PRODUCTION - Uses base values.yaml (already production-ready)
helm upgrade --install auth-service ./auth-service \
  --namespace prod

# DEVELOPMENT - Overrides with dev values
helm upgrade --install auth-service ./auth-service \
  --namespace dev \
  -f environments/dev/auth-service.yaml    # ← Override file

# QA - Overrides with qa values
helm upgrade --install auth-service ./auth-service \
  --namespace qa \
  -f environments/qa/auth-service.yaml     # ← Override file
```

**What `-f environments/dev/auth-service.yaml` does:**
- Takes base `values.yaml` as starting point
- MERGES the dev file on top
- Only values specified in dev file are changed
- Everything else stays as production defaults

---

## ⏰ When Helm Commands Run <a name="when-helm-runs"></a>

### The CI/CD Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GITHUB ACTIONS WORKFLOW                               │
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  TRIGGER    │    │   BUILD     │    │    PUSH     │    │   DEPLOY    │  │
│  │             │    │             │    │             │    │             │  │
│  │ • git push  │ ─→ │ • mvn build │ ─→ │ • docker    │ ─→ │ • HELM      │  │
│  │ • manual    │    │ • run tests │    │   push to   │    │   COMMANDS  │  │
│  │   dispatch  │    │             │    │   ECR       │    │   RUN HERE! │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                              │
│        Stage 1            Stage 2          Stage 3          Stage 4         │
│      (Seconds)          (2-3 mins)       (30 secs)        (1-2 mins)       │
└─────────────────────────────────────────────────────────────────────────────┘
                                                                ▲
                                                                │
                                                    HELM RUNS AT THIS STAGE
```

### What Happens in the Deploy Stage

```yaml
# From ci-cd-auth.yml - The DEPLOY step

- name: "🚀 Deploy to ${{ env.TARGET_ENV }}"
  env:
    ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    IMAGE_TAG: ${{ steps.vars.outputs.short_sha }}
  run: |
    # 1. Determine environment override file
    ENV_FILE="helm-charts/environments/${{ env.TARGET_ENV }}/${{ env.SERVICE_NAME }}.yaml"
    
    # 2. Build the helm command
    HELM_CMD="helm upgrade --install ${{ env.SERVICE_NAME }} ${{ env.HELM_CHART_PATH }}"
    
    # 3. Add namespace (dev, qa, or prod)
    HELM_CMD="$HELM_CMD --namespace ${{ env.TARGET_ENV }} --create-namespace"
    
    # 4. Add environment file if exists (for dev/qa)
    if [ -f "$ENV_FILE" ]; then
      HELM_CMD="$HELM_CMD -f $ENV_FILE"
    fi
    
    # 5. Override image tag with just-built image
    HELM_CMD="$HELM_CMD --set auth.image.tag=$IMAGE_TAG"
    
    # 6. EXECUTE - This is where Kubernetes resources are created!
    $HELM_CMD
```

### Timeline of a Deployment

```
00:00  Developer pushes code to main branch
       └─→ GitHub detects push, triggers workflow

00:05  Workflow starts
       └─→ Checks out code from repo

00:15  Java/Maven setup
       └─→ Downloads dependencies, cached

01:00  Build & Test
       └─→ mvn clean verify (compiles, runs tests)

03:00  Docker Build
       └─→ Creates container image

03:30  Docker Push
       └─→ Uploads image to ECR

04:00  ★ HELM COMMANDS RUN ★
       └─→ Connects to EKS cluster
       └─→ helm upgrade --install auth-service ./auth-service \
             --namespace prod \
             --set auth.image.tag=abc12345
       
       Helm does:
       ├── Reads values.yaml (or override file)
       ├── Renders templates with values
       ├── Sends manifests to Kubernetes API
       └── Kubernetes creates/updates:
           ├── Deployment (pods)
           ├── Service (networking)
           ├── HPA (autoscaling)
           └── ConfigMap, Secrets, etc.

05:00  Verify Deployment
       └─→ kubectl rollout status deployment/auth-depl -n prod
       └─→ Waits for pods to be Running

05:30  ✅ COMPLETE
```

---

## 🔄 Flexible CI/CD for Multiple Environments <a name="flexible-cicd"></a>

### How the Updated Workflow Works

**Current Setup (Updated auth-service workflow):**

```yaml
on:
  # MANUAL TRIGGER - Pick any environment
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'prod'
        type: choice
        options:
          - dev
          - qa
          - prod

  # AUTO TRIGGER - Always goes to prod
  push:
    branches: [main]
    paths:
      - 'microservice-backend/auth-service/**'
```

### How to Deploy to Different Environments

#### Option 1: Automatic (Push to main) → PROD

```bash
# Any push to main with auth-service changes
git add microservice-backend/auth-service/
git commit -m "Fix auth bug"
git push origin main

# Result: Automatically deploys to PROD namespace
```

#### Option 2: Manual Dispatch → Any Environment

```
GitHub UI → Actions → "🔐 Auth Service CI/CD" → "Run workflow"
                                                      │
                                         ┌────────────┴────────────┐
                                         │  Select environment:    │
                                         │  ○ dev                  │
                                         │  ○ qa                   │
                                         │  ● prod                 │
                                         │                         │
                                         │  [Run workflow]         │
                                         └─────────────────────────┘
```

### The Environment Logic

```yaml
env:
  # If manual dispatch with input, use input
  # If automatic push, default to 'prod'
  TARGET_ENV: ${{ github.event.inputs.environment || 'prod' }}

jobs:
  build-and-deploy:
    # GitHub Environment (for secrets/approvals):
    # - 'dev' → uses 'dev' environment
    # - 'qa' → uses 'qa' environment
    # - 'prod' (or empty) → uses 'production' environment
    environment: ${{ (github.event.inputs.environment == 'prod' || 
                      github.event.inputs.environment == '') && 
                     'production' || github.event.inputs.environment }}
```

### What Changes Per Environment

| Component | DEV | QA | PROD |
|-----------|-----|----|----- |
| Namespace | `dev` | `qa` | `prod` |
| Values File | `environments/dev/*.yaml` | `environments/qa/*.yaml` | Base `values.yaml` |
| GitHub Environment | `dev` | `qa` | `production` |
| Secrets | `${{ secrets.* }}` from dev | `${{ secrets.* }}` from qa | `${{ secrets.* }}` from production |

---

## 🔀 Complete Deployment Flow <a name="complete-flow"></a>

### Visual Flow: Dev → QA → Prod

```
                            DEVELOPMENT
                    ┌─────────────────────────┐
                    │  1. Developer writes     │
                    │     code on feature      │
                    │     branch               │
                    │                          │
                    │  2. Manual dispatch to   │
                    │     DEV environment      │
                    │     ↓                    │
                    │  helm ... --namespace dev│
                    │  -f environments/dev/... │
                    └───────────┬─────────────┘
                                │
                                ▼
                               QA
                    ┌─────────────────────────┐
                    │  3. QA team tests        │
                    │                          │
                    │  4. Manual dispatch to   │
                    │     QA environment       │
                    │     ↓                    │
                    │  helm ... --namespace qa │
                    │  -f environments/qa/...  │
                    └───────────┬─────────────┘
                                │
                                ▼
                           PRODUCTION
                    ┌─────────────────────────┐
                    │  5. Merge PR to main     │
                    │     ↓                    │
                    │  Auto-triggers workflow  │
                    │     ↓                    │
                    │  helm ... --namespace    │
                    │     prod                 │
                    │  (uses base values.yaml) │
                    └─────────────────────────┘
```

### Example: Complete Auth Service Deployment

```bash
# ═══════════════════════════════════════════════════════════════════
# STEP 1: Deploy to DEV (Manual from GitHub UI)
# ═══════════════════════════════════════════════════════════════════

# Workflow runs with inputs.environment = 'dev'
# Resulting command:

helm upgrade --install auth-service helm-charts/auth-service \
  --namespace dev \
  --create-namespace \
  -f helm-charts/environments/dev/auth-service.yaml \
  --set auth.image.repository=855561838951.dkr.ecr.us-east-1.amazonaws.com/auth-service \
  --set auth.image.tag=abc12345 \
  --wait --timeout 5m

# Creates in Kubernetes:
# - Namespace: dev (if not exists)
# - Deployment: auth-depl (1 replica, 256Mi memory)
# - Service: auth-service
# - NO HPA (disabled in dev)


# ═══════════════════════════════════════════════════════════════════
# STEP 2: Deploy to QA (Manual from GitHub UI)
# ═══════════════════════════════════════════════════════════════════

helm upgrade --install auth-service helm-charts/auth-service \
  --namespace qa \
  --create-namespace \
  -f helm-charts/environments/qa/auth-service.yaml \
  --set auth.image.repository=855561838951.dkr.ecr.us-east-1.amazonaws.com/auth-service \
  --set auth.image.tag=abc12345 \
  --wait --timeout 5m

# Creates in Kubernetes:
# - Namespace: qa
# - Deployment: auth-depl (2 replicas, 512Mi memory)
# - Service: auth-service
# - HPA: auth-hpa (min: 2, max: 6)


# ═══════════════════════════════════════════════════════════════════
# STEP 3: Deploy to PROD (Auto on push to main)
# ═══════════════════════════════════════════════════════════════════

helm upgrade --install auth-service helm-charts/auth-service \
  --namespace prod \
  --create-namespace \
  --set auth.image.repository=855561838951.dkr.ecr.us-east-1.amazonaws.com/auth-service \
  --set auth.image.tag=abc12345 \
  --wait --timeout 5m

# Creates in Kubernetes:
# - Namespace: prod
# - Deployment: auth-depl (3 replicas, 1Gi memory)
# - Service: auth-service
# - HPA: auth-hpa (min: 3, max: 10)
# - PDB: auth-pdb (minAvailable: 2)
```

---

## 📊 Summary: Your Questions Answered

### Q1: How is it flexible when I want to deploy to dev or qa?

**Answer:** The workflow now has `workflow_dispatch` with environment selector:
- **Push to main** → Always deploys to **PROD** (automated)
- **Manual dispatch** → Choose **dev**, **qa**, or **prod**

```yaml
workflow_dispatch:
  inputs:
    environment:
      type: choice
      options: [dev, qa, prod]
```

### Q2: How do environments folder YAML files get used?

**Answer:** The helm command conditionally includes them:

```bash
# For DEV/QA: Uses override file
helm ... -f environments/dev/auth-service.yaml

# For PROD: Uses base values.yaml only (already production-ready)
helm ...  # No -f flag needed
```

### Q3: Why namespaces? How do enterprise apps use them?

**Answer:** Namespaces provide:
- **Isolation**: dev/qa/prod don't interfere
- **Same names**: `auth-service` exists in all 3
- **Different configs**: 1 replica in dev, 10 in prod
- **Access control**: Developers can't access prod namespace
- **Resource limits**: Dev gets 10%, prod gets 90%

### Q4: When do helm commands run?

**Answer:** In the **DEPLOY stage** of CI/CD pipeline:
1. Trigger (push/manual)
2. Build (maven/npm)
3. Push image to ECR
4. **→ HELM RUNS HERE ←** (creates K8s resources)
5. Verify deployment

---

## 🎯 Quick Reference

| Action | Command | Result |
|--------|---------|--------|
| Deploy to dev | Manual dispatch → dev | `--namespace dev -f environments/dev/...` |
| Deploy to qa | Manual dispatch → qa | `--namespace qa -f environments/qa/...` |
| Deploy to prod | Push to main (auto) | `--namespace prod` (base values) |
| Check pods | `kubectl get pods -n <env>` | See running containers |
| Check deployments | `kubectl get deploy -n <env>` | See deployments |
| Switch namespace | `kubectl config set-context --current --namespace=prod` | Change default |
