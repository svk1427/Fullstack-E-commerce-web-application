# =============================================================================
# HELM CHARTS ENTERPRISE DEPLOYMENT GUIDE
# =============================================================================
# Multi-Environment Helm Deployment Strategy
# Environments: DEV → QA → PROD
# =============================================================================

## 📁 Directory Structure

```
helm-charts/
├── api-gateway/           # Base chart (PROD values by default)
├── auth-service/          # Base chart (PROD values by default)
├── cart-service/          # Base chart (PROD values by default)
├── category-service/      # Base chart (PROD values by default)
├── ingress-alb/           # Base chart (PROD values by default)
├── notification-service/  # Base chart (PROD values by default)
├── order-service/         # Base chart (PROD values by default)
├── product-service/       # Base chart (PROD values by default)
├── service-registry/      # Base chart (PROD values by default)
├── user-service/          # Base chart (PROD values by default)
├── web-app/               # Base chart (PROD values by default)
│
└── environments/          # Environment-specific overrides
    ├── dev/               # Development overrides (minimal resources)
    │   ├── api-gateway.yaml
    │   ├── auth-service.yaml
    │   ├── cart-service.yaml
    │   ├── category-service.yaml
    │   ├── ingress-alb.yaml
    │   ├── notification-service.yaml
    │   ├── order-service.yaml
    │   ├── product-service.yaml
    │   ├── service-registry.yaml
    │   ├── user-service.yaml
    │   └── web-app.yaml
    │
    ├── qa/                # QA overrides (moderate resources)
    │   ├── api-gateway.yaml
    │   ├── auth-service.yaml
    │   ├── cart-service.yaml
    │   ├── category-service.yaml
    │   ├── ingress-alb.yaml
    │   ├── notification-service.yaml
    │   ├── order-service.yaml
    │   ├── product-service.yaml
    │   ├── service-registry.yaml
    │   ├── user-service.yaml
    │   └── web-app.yaml
    │
    └── prod/              # Production overrides (domain-specific only)
        ├── README.md
        ├── ingress-alb.yaml
        └── web-app.yaml
```

---

## 🚀 Deployment Commands

### Production Deployment (Default - Recommended)

Base values.yaml files ARE production-ready. Simply deploy:

```bash
# Set namespace
NAMESPACE="prod"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy in correct order
# 1. Service Registry (Eureka) - must be first
helm upgrade --install service-registry ./service-registry \
  --namespace $NAMESPACE \
  --wait --timeout 5m

# 2. Core Microservices (can be parallel)
helm upgrade --install auth-service ./auth-service --namespace $NAMESPACE &
helm upgrade --install user-service ./user-service --namespace $NAMESPACE &
helm upgrade --install product-service ./product-service --namespace $NAMESPACE &
helm upgrade --install category-service ./category-service --namespace $NAMESPACE &
helm upgrade --install cart-service ./cart-service --namespace $NAMESPACE &
helm upgrade --install order-service ./order-service --namespace $NAMESPACE &
helm upgrade --install notification-service ./notification-service --namespace $NAMESPACE &
wait

# 3. API Gateway
helm upgrade --install api-gateway ./api-gateway \
  --namespace $NAMESPACE \
  --wait --timeout 3m

# 4. Frontend
helm upgrade --install web-app ./web-app \
  --namespace $NAMESPACE \
  -f environments/prod/web-app.yaml

# 5. Ingress ALB
helm upgrade --install ingress-alb ./ingress-alb \
  --namespace $NAMESPACE \
  -f environments/prod/ingress-alb.yaml
```

### Development Deployment

```bash
NAMESPACE="dev"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy with dev overrides
helm upgrade --install service-registry ./service-registry \
  --namespace $NAMESPACE \
  -f environments/dev/service-registry.yaml

helm upgrade --install auth-service ./auth-service \
  --namespace $NAMESPACE \
  -f environments/dev/auth-service.yaml

# ... repeat for all services
```

### QA Deployment

```bash
NAMESPACE="qa"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy with qa overrides
helm upgrade --install service-registry ./service-registry \
  --namespace $NAMESPACE \
  -f environments/qa/service-registry.yaml

# ... repeat for all services
```

---

## 📊 Environment Comparison

| Configuration        | DEV              | QA               | PROD             |
|---------------------|------------------|------------------|------------------|
| **Replicas**        | 1                | 2                | 3                |
| **HPA Enabled**     | ❌ No            | ✅ Yes           | ✅ Yes           |
| **Max Replicas**    | 2                | 4-6              | 10-20            |
| **PDB Enabled**     | ❌ No            | ✅ Yes           | ✅ Yes           |
| **Anti-Affinity**   | ❌ No            | ✅ Yes           | ✅ Yes           |
| **CPU Requests**    | 100m             | 200-250m         | 250-500m         |
| **Memory Requests** | 128-256Mi        | 384Mi            | 512Mi-1Gi        |
| **CPU Limits**      | 500m             | 1000m            | 2000m            |
| **Memory Limits**   | 512Mi            | 1Gi              | 2Gi              |
| **Log Level**       | DEBUG            | INFO             | WARN             |
| **SSL**             | ❌ HTTP only     | ✅ HTTPS         | ✅ HTTPS         |
| **WAF**             | ❌ No            | ❌ No            | ✅ Yes           |
| **Shield**          | ❌ No            | ❌ No            | ✅ Yes           |
| **Access Logs**     | ❌ No            | ✅ Yes           | ✅ Yes           |
| **Deletion Protect**| ❌ No            | ❌ No            | ✅ Yes           |

---

## 🔧 Service-Specific Configurations

### High-Traffic Services (Higher Max Replicas)

| Service          | PROD Max Replicas | Reason                          |
|------------------|-------------------|----------------------------------|
| web-app          | 20                | User-facing, static content      |
| product-service  | 15                | Heavy read traffic               |
| api-gateway      | 12                | All traffic passes through       |
| order-service    | 10                | Critical business function       |

### Standard Services

| Service             | PROD Max Replicas | Reason                          |
|---------------------|-------------------|----------------------------------|
| auth-service        | 8                 | Authentication load              |
| user-service        | 8                 | User profile requests            |
| cart-service        | 8                 | Session-based                    |
| category-service    | 8                 | Catalog queries                  |
| notification-service| 6                 | Async, lower priority            |
| service-registry    | 5                 | Infrastructure, stable load      |

---

## 🔐 Secrets Management

### Method 1: Helm Set (CI/CD)

```bash
helm upgrade --install auth-service ./auth-service \
  --namespace prod \
  --set secret.JWT_SECRET=$JWT_SECRET \
  --set secret.MONGODB_URI=$MONGODB_URI
```

### Method 2: External Secrets Operator (Recommended)

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: auth-service-secrets
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager
  target:
    name: auth-secret
  data:
    - secretKey: JWT_SECRET
      remoteRef:
        key: prod/ecommerce/auth
        property: jwt_secret
```

### Method 3: Sealed Secrets

```bash
# Encrypt secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml
```

---

## 📦 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name prod-eks-cluster
      
      - name: Deploy Services
        run: |
          cd helm-charts
          
          # Deploy each service
          helm upgrade --install service-registry ./service-registry \
            --namespace prod --wait
          
          helm upgrade --install api-gateway ./api-gateway \
            --namespace prod \
            --set apigateway.image.tag=${{ github.sha }}
          
          # ... other services
```

---

## ✅ Deployment Verification

```bash
# Check all pods
kubectl get pods -n prod -o wide

# Check HPA status
kubectl get hpa -n prod

# Check PDB status
kubectl get pdb -n prod

# Check services
kubectl get svc -n prod

# Check ingress
kubectl get ingress -n prod

# View pod distribution across nodes
kubectl get pods -n prod -o wide | awk '{print $7}' | sort | uniq -c
```

---

## 🔄 Rollback Procedure

```bash
# View release history
helm history api-gateway -n prod

# Rollback to previous version
helm rollback api-gateway 1 -n prod

# Rollback to specific revision
helm rollback api-gateway 3 -n prod
```

---

## 📈 Scaling Override

```bash
# Manual scale (temporary)
kubectl scale deployment api-gateway --replicas=5 -n prod

# Permanent scale (update values)
helm upgrade api-gateway ./api-gateway \
  --namespace prod \
  --set apigateway.replicas=5 \
  --set apigateway.autoscaling.minReplicas=5
```
