# 🚀 E-Commerce Microservices - Complete CI/CD & Deployment Guide

## End-to-End Flow: From Code to Production

This guide explains the complete journey of code from your local machine to a production-ready application accessible in the browser.

---

## 📋 Table of Contents

1. [Architecture Overview](#-architecture-overview)
2. [Repository Structure](#-repository-structure)
3. [Prerequisites Setup](#-prerequisites-setup)
4. [Infrastructure Deployment](#-infrastructure-deployment)
5. [CI/CD Pipeline Flow](#-cicd-pipeline-flow)
6. [Step-by-Step Deployment](#-step-by-step-deployment)
7. [Accessing the Application](#-accessing-the-application)
8. [Monitoring & Troubleshooting](#-monitoring--troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              PRODUCTION ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────────────────────────┐  │
│  │   GitHub    │──────│  GitHub     │──────│        Amazon ECR               │  │
│  │  Repository │      │  Actions    │      │  (Container Registry)           │  │
│  └─────────────┘      └─────────────┘      └─────────────────────────────────┘  │
│                              │                           │                        │
│                              │                           │                        │
│                              ▼                           ▼                        │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                        Amazon EKS Cluster                                  │  │
│  │  ┌─────────────────────────────────────────────────────────────────────┐  │  │
│  │  │                         PROD Namespace                               │  │  │
│  │  │                                                                       │  │  │
│  │  │   ┌──────────────┐    ┌──────────────────────────────────────────┐  │  │  │
│  │  │   │ AWS ALB      │────│              API Gateway                  │  │  │  │
│  │  │   │ (Ingress)    │    │              (Port 8080)                  │  │  │  │
│  │  │   └──────────────┘    └──────────────────────────────────────────┘  │  │  │
│  │  │          │                              │                            │  │  │
│  │  │          │                              ▼                            │  │  │
│  │  │          │            ┌─────────────────────────────────┐           │  │  │
│  │  │          │            │       Service Registry          │           │  │  │
│  │  │          │            │       (Eureka - 8761)           │           │  │  │
│  │  │          │            └─────────────────────────────────┘           │  │  │
│  │  │          │                              │                            │  │  │
│  │  │          │            ┌─────────────────┴─────────────────┐         │  │  │
│  │  │          │            ▼                                   ▼         │  │  │
│  │  │          │   ┌─────────────────┐               ┌─────────────────┐  │  │  │
│  │  │          │   │  Auth Service   │               │  User Service   │  │  │  │
│  │  │          │   │   (Port 9030)   │               │  (Port 9050)    │  │  │  │
│  │  │          │   └─────────────────┘               └─────────────────┘  │  │  │
│  │  │          │                                                           │  │  │
│  │  │          │   ┌─────────────────┐               ┌─────────────────┐  │  │  │
│  │  │          │   │Product Service  │               │Category Service │  │  │  │
│  │  │          │   │  (Port 9010)    │               │  (Port 9000)    │  │  │  │
│  │  │          │   └─────────────────┘               └─────────────────┘  │  │  │
│  │  │          │                                                           │  │  │
│  │  │          │   ┌─────────────────┐               ┌─────────────────┐  │  │  │
│  │  │          │   │  Cart Service   │               │  Order Service  │  │  │  │
│  │  │          │   │  (Port 9060)    │               │  (Port 9070)    │  │  │  │
│  │  │          │   └─────────────────┘               └─────────────────┘  │  │  │
│  │  │          │                                                           │  │  │
│  │  │          │   ┌─────────────────────────────────────────────────────┐│  │  │
│  │  │          │   │              Notification Service (9020)            ││  │  │
│  │  │          │   └─────────────────────────────────────────────────────┘│  │  │
│  │  │          │                                                           │  │  │
│  │  │          │                                                           │  │  │
│  │  │          ▼                                                           │  │  │
│  │  │   ┌──────────────┐                                                   │  │  │
│  │  │   │   Web App    │◄──────── (React/Vite Frontend - Port 80)         │  │  │
│  │  │   │   (NGINX)    │                                                   │  │  │
│  │  │   └──────────────┘                                                   │  │  │
│  │  │                                                                       │  │  │
│  │  └─────────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
│                                     │                                             │
│                                     ▼                                             │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         MongoDB Atlas (Database)                           │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
Fullstack-E-commerce-web-application/
│
├── 📂 .github/workflows/              # CI/CD Pipelines
│   ├── ci-cd-gateway.yml              # API Gateway pipeline
│   ├── ci-cd-auth.yml                 # Auth Service pipeline
│   ├── ci-cd-user.yml                 # User Service pipeline
│   ├── ci-cd-product.yml              # Product Service pipeline
│   ├── ci-cd-category.yml             # Category Service pipeline
│   ├── ci-cd-cart.yml                 # Cart Service pipeline
│   ├── ci-cd-order.yml                # Order Service pipeline
│   ├── ci-cd-notification.yml         # Notification Service pipeline
│   ├── ci-cd-registry.yml             # Service Registry pipeline
│   ├── ci-cd-web.yml                  # Frontend pipeline
│   ├── ci-cd-ingress.yml              # ALB Ingress pipeline
│   └── reusable-java-service.yml      # Reusable workflow template
│
├── 📂 frontend/                        # React/Vite Frontend
│   ├── src/
│   ├── public/
│   ├── Dockerfile
│   └── package.json
│
├── 📂 microservice-backend/            # Java Spring Boot Services
│   ├── api-gateway/
│   ├── auth-service/
│   ├── user-service/
│   ├── product-service/
│   ├── category-service/
│   ├── cart-service/
│   ├── order-service/
│   ├── notification-service/
│   └── service-registry/
│
├── 📂 helm-charts/                     # Kubernetes Helm Charts
│   ├── api-gateway/
│   │   ├── Chart.yaml
│   │   ├── values.yaml                 # PRODUCTION values (default)
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── config-map.yaml
│   │       ├── hpa.yaml
│   │       └── pdb.yaml
│   │
│   ├── environments/                   # Environment-specific overrides
│   │   ├── dev/
│   │   │   ├── environment.yaml        # DEV environment config
│   │   │   ├── api-gateway.yaml
│   │   │   ├── auth-service.yaml
│   │   │   └── ...
│   │   ├── qa/
│   │   │   ├── environment.yaml        # QA environment config
│   │   │   └── ...
│   │   └── prod/
│   │       ├── environment.yaml        # PROD environment config
│   │       ├── ingress-alb.yaml
│   │       └── web-app.yaml
│   │
│   └── [other-services]/
│
├── 📂 terraform/                       # Infrastructure as Code
│   └── us-east-1/
│       ├── c1-versions.tf
│       ├── c2-vpc.tf
│       ├── c3-eks-cluster.tf
│       ├── c4-eks-nodegroups.tf
│       └── c5-05-securitygroups-eks.tf
│
└── 📂 scripts/                         # Deployment scripts
    ├── verify-environment.sh
    └── deploy-prod.sh
```

---

## ⚙️ Prerequisites Setup

### 1. AWS Account Configuration

```bash
# Required AWS Resources
- AWS Account ID: 855561838951 (Production)
- Region: us-east-1
- EKS Cluster: prod-eks-cluster
- ECR Repositories: One per service

# AWS CLI Setup
aws configure
AWS Access Key ID: [YOUR_ACCESS_KEY]
AWS Secret Access Key: [YOUR_SECRET_KEY]
Default region: us-east-1
```

### 2. GitHub Secrets Configuration

Navigate to: `GitHub Repository → Settings → Secrets and variables → Actions`

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | `wJalrXUtnFEMI/K7MDENG/...` |
| `EKS_CLUSTER` | EKS Cluster Name | `prod-eks-cluster` |
| `ECR_GATEWAY_REPOSITORY` | ECR repo name | `api-gateway` |
| `ECR_AUTH_REPOSITORY` | ECR repo name | `auth-service` |
| `ECR_USER_REPOSITORY` | ECR repo name | `user-service` |
| `ECR_PRODUCT_REPOSITORY` | ECR repo name | `product-service` |
| `ECR_CATEGORY_REPOSITORY` | ECR repo name | `category-service` |
| `ECR_CART_REPOSITORY` | ECR repo name | `cart-service` |
| `ECR_ORDER_REPOSITORY` | ECR repo name | `order-service` |
| `ECR_NOTIFICATION_REPOSITORY` | ECR repo name | `notification-service` |
| `ECR_REGISTRY_REPOSITORY` | ECR repo name | `service-registry` |
| `ECR_WEB_REPOSITORY` | ECR repo name | `web-app` |
| `SPRING_DATA_MONGODB_URI_*` | MongoDB connection strings | `mongodb+srv://...` |

### 3. GitHub Environments Setup

Navigate to: `GitHub Repository → Settings → Environments`

Create these environments with protection rules:

| Environment | Protection Rules |
|-------------|-----------------|
| `dev` | None (auto-deploy) |
| `qa` | Required reviewers: 1 |
| `production` | Required reviewers: 2, Wait timer: 5 min |

---

## 🏗️ Infrastructure Deployment

### Step 1: Bootstrap Terraform Backend

```bash
cd bootstrap/
terraform init
terraform apply
```

### Step 2: Deploy Core Infrastructure

```bash
cd terraform/us-east-1/

# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

This creates:
- ✅ VPC with public/private subnets
- ✅ EKS Cluster
- ✅ EKS Node Groups
- ✅ Security Groups (ALB, Nodes, Cluster, Database)
- ✅ IAM Roles

### Step 3: Install AWS Load Balancer Controller

```bash
# Update kubeconfig
aws eks update-kubeconfig --name prod-eks-cluster --region us-east-1

# Install ALB Controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=prod-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

---

## 🔄 CI/CD Pipeline Flow

### Pipeline Stages

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CI/CD PIPELINE FLOW                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌────────┐│
│  │  COMMIT  │───▶│  BUILD   │───▶│   TEST   │───▶│  DOCKER  │───▶│  PUSH  ││
│  │  CODE    │    │  (Maven) │    │  (JUnit) │    │  BUILD   │    │  ECR   ││
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘    └────────┘│
│                                                                       │      │
│                                                                       ▼      │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                        DEPLOYMENT STAGES                              │   │
│  │                                                                        │   │
│  │   ┌─────────┐         ┌─────────┐         ┌─────────────┐            │   │
│  │   │   DEV   │────────▶│   QA    │────────▶│ PRODUCTION  │            │   │
│  │   │  (Auto) │         │(Manual) │         │  (Manual)   │            │   │
│  │   └─────────┘         └─────────┘         └─────────────┘            │   │
│  │       │                   │                     │                     │   │
│  │       ▼                   ▼                     ▼                     │   │
│  │  helm upgrade        helm upgrade         helm upgrade                │   │
│  │  -f dev/values.yaml  -f qa/values.yaml    (prod default)             │   │
│  │                                                                        │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Trigger Conditions

| Trigger | DEV Deploy | QA Deploy | PROD Deploy |
|---------|------------|-----------|-------------|
| Push to `main` | ✅ Automatic | ❌ | ❌ |
| Pull Request | ❌ (Build only) | ❌ | ❌ |
| Manual Dispatch (dev) | ✅ | ❌ | ❌ |
| Manual Dispatch (qa) | ✅ | ✅ | ❌ |
| Manual Dispatch (prod) | ✅ | ❌ | ✅ |

---

## 📝 Step-by-Step Deployment

### Phase 1: Initial Setup (One-time)

```bash
# 1. Clone repository
git clone https://github.com/your-org/Fullstack-E-commerce-web-application.git
cd Fullstack-E-commerce-web-application

# 2. Create ECR repositories (one per service)
aws ecr create-repository --repository-name api-gateway
aws ecr create-repository --repository-name auth-service
aws ecr create-repository --repository-name user-service
aws ecr create-repository --repository-name product-service
aws ecr create-repository --repository-name category-service
aws ecr create-repository --repository-name cart-service
aws ecr create-repository --repository-name order-service
aws ecr create-repository --repository-name notification-service
aws ecr create-repository --repository-name service-registry
aws ecr create-repository --repository-name web-app

# 3. Configure GitHub Secrets (see Prerequisites section)
```

### Phase 2: Deploy to DEV (Automatic)

```bash
# Make changes to code
git add .
git commit -m "feat: add new product feature"
git push origin main

# Pipeline automatically:
# 1. Builds the service
# 2. Runs tests
# 3. Pushes Docker image to ECR
# 4. Deploys to DEV namespace
```

### Phase 3: Promote to QA (Manual)

1. Go to **GitHub → Actions → Select workflow**
2. Click **"Run workflow"**
3. Select **environment: qa**
4. Click **"Run workflow"**
5. Wait for approval (if configured)

### Phase 4: Deploy to Production (Manual with Approval)

1. Go to **GitHub → Actions → Select workflow**
2. Click **"Run workflow"**
3. Select **environment: prod**
4. Click **"Run workflow"**
5. **Wait for required approvals**
6. Monitor deployment

### Phase 5: Deploy All Services (Full Deployment Order)

```bash
# Deployment Order (Important!)

# 1. Service Registry (Eureka) - MUST BE FIRST
helm upgrade --install service-registry helm-charts/service-registry --namespace prod

# 2. Wait for Eureka to be ready
kubectl wait --for=condition=ready pod -l app=registry -n prod --timeout=300s

# 3. Core Microservices (can be parallel)
helm upgrade --install auth-service helm-charts/auth-service --namespace prod &
helm upgrade --install user-service helm-charts/user-service --namespace prod &
helm upgrade --install product-service helm-charts/product-service --namespace prod &
helm upgrade --install category-service helm-charts/category-service --namespace prod &
helm upgrade --install cart-service helm-charts/cart-service --namespace prod &
helm upgrade --install order-service helm-charts/order-service --namespace prod &
helm upgrade --install notification-service helm-charts/notification-service --namespace prod &
wait

# 4. API Gateway (routes to microservices)
helm upgrade --install api-gateway helm-charts/api-gateway --namespace prod

# 5. Frontend
helm upgrade --install web-app helm-charts/web-app \
  -f helm-charts/environments/prod/web-app.yaml --namespace prod

# 6. Ingress ALB (exposes to internet) - LAST
helm upgrade --install ingress-alb helm-charts/ingress-alb \
  -f helm-charts/environments/prod/ingress-alb.yaml --namespace prod
```

---

## 🌐 Accessing the Application

### Get ALB DNS Name

```bash
# Get Ingress details
kubectl get ingress -n prod

# Output:
# NAME              CLASS   HOSTS                            ADDRESS                                     PORTS
# prod-alb-ingress  alb     www.yourdomain.com,api...        k8s-prod-xxxxx.us-east-1.elb.amazonaws.com  80,443
```

### Configure DNS (Route 53)

1. Go to **AWS Route 53 → Hosted Zones**
2. Create A records:

| Record Name | Type | Alias | Target |
|-------------|------|-------|--------|
| www.yourdomain.com | A | Yes | ALB DNS |
| api.yourdomain.com | A | Yes | ALB DNS |

### Access URLs

| Environment | Frontend URL | API URL |
|-------------|-------------|---------|
| DEV | https://dev.yourdomain.com | https://dev-api.yourdomain.com |
| QA | https://qa.yourdomain.com | https://qa-api.yourdomain.com |
| PROD | https://www.yourdomain.com | https://api.yourdomain.com |

### Verify Application

```bash
# Frontend health check
curl -I https://www.yourdomain.com

# API Gateway health check
curl https://api.yourdomain.com/actuator/health

# Expected response:
# {"status":"UP"}
```

---

## 📊 Monitoring & Troubleshooting

### Check Deployment Status

```bash
# All pods in production
kubectl get pods -n prod -o wide

# HPA status
kubectl get hpa -n prod

# PDB status
kubectl get pdb -n prod

# Services
kubectl get svc -n prod

# Ingress
kubectl describe ingress -n prod
```

### View Logs

```bash
# API Gateway logs
kubectl logs -l app=gateway -n prod --tail=100 -f

# Specific service logs
kubectl logs -l app=auth -n prod --tail=100 -f
kubectl logs -l app=product -n prod --tail=100 -f
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Pods not starting | `kubectl describe pod <pod-name> -n prod` |
| Service unavailable | Check Eureka: `kubectl logs -l app=registry -n prod` |
| ALB not routing | `kubectl describe ingress -n prod` |
| Health check failing | Check `/actuator/health` endpoint |
| Database connection | Verify MongoDB URI in secrets |

### Rollback

```bash
# View release history
helm history api-gateway -n prod

# Rollback to previous version
helm rollback api-gateway 1 -n prod
```

---

## 🔐 Environment Verification

Before any production deployment, always verify:

```bash
# Run verification script
./scripts/verify-environment.sh prod

# Output:
# ╔═══════════════════════════════════════════════════════════════╗
# ║            ⚠️  PRODUCTION ENVIRONMENT ⚠️                       ║
# ║            PROCEED WITH EXTREME CAUTION                        ║
# ╚═══════════════════════════════════════════════════════════════╝
#
# ✓ AWS Account: 855561838951
# ✓ EKS Cluster: prod-eks-cluster
#
# Type 'DEPLOY-PROD' to confirm:
```

---

## 📈 Production Scaling

| Service | Min Replicas | Max Replicas | CPU Target |
|---------|--------------|--------------|------------|
| API Gateway | 3 | 12 | 70% |
| Service Registry | 3 | 5 | 70% |
| Auth Service | 3 | 8 | 70% |
| User Service | 3 | 8 | 70% |
| Product Service | 3 | 15 | 70% |
| Category Service | 3 | 8 | 70% |
| Cart Service | 3 | 8 | 70% |
| Order Service | 3 | 10 | 70% |
| Notification Service | 2 | 6 | 70% |
| Web App | 3 | 20 | 70% |

---

## ✅ Deployment Checklist

### Before Deployment
- [ ] All tests passing in CI
- [ ] Code reviewed and approved
- [ ] Secrets configured in GitHub
- [ ] Environment verified (`./scripts/verify-environment.sh prod`)
- [ ] Rollback plan documented

### After Deployment
- [ ] All pods running (`kubectl get pods -n prod`)
- [ ] Health checks passing
- [ ] Application accessible in browser
- [ ] Logs verified (no errors)
- [ ] Monitoring alerts configured

---

## 🎯 Quick Reference Commands

```bash
# Deploy single service
helm upgrade --install api-gateway helm-charts/api-gateway -n prod

# Deploy with environment override
helm upgrade --install api-gateway helm-charts/api-gateway \
  -f helm-charts/environments/dev/api-gateway.yaml -n dev

# Check deployment
kubectl rollout status deployment/gateway-depl -n prod

# Scale manually
kubectl scale deployment/gateway-depl --replicas=5 -n prod

# View all resources
kubectl get all -n prod

# Delete release
helm uninstall api-gateway -n prod
```

---

**🎉 Congratulations!** You now have a complete understanding of the end-to-end deployment flow from code commit to production access.

For questions or issues, create a GitHub Issue or contact the DevOps team.
