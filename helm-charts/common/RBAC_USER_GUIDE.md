# Kubernetes RBAC Guide - Users, Groups, and Permissions

## Overview

RBAC (Role-Based Access Control) in Kubernetes controls **who** can do **what** on **which resources**.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            RBAC COMPONENTS                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   WHO (Subjects)              WHAT (Verbs)              WHICH (Resources)       │
│   ┌─────────────────┐         ┌──────────────┐          ┌─────────────────┐    │
│   │ Users           │         │ get          │          │ pods            │    │
│   │ Groups          │         │ list         │          │ deployments     │    │
│   │ ServiceAccounts │         │ watch        │          │ services        │    │
│   └────────┬────────┘         │ create       │          │ secrets         │    │
│            │                  │ update       │          │ configmaps      │    │
│            │                  │ patch        │          │ nodes           │    │
│            ▼                  │ delete       │          │ namespaces      │    │
│   ┌─────────────────┐         │ exec         │          │ ingresses       │    │
│   │ RoleBinding     │         │ portforward  │          │ persistentvolumes│   │
│   │ ClusterRoleBinding│       └──────────────┘          └─────────────────┘    │
│   └────────┬────────┘                                                           │
│            │                                                                     │
│            ▼                                                                     │
│   ┌─────────────────┐                                                           │
│   │ Role            │  ← Namespace-scoped (e.g., only "purely" namespace)       │
│   │ ClusterRole     │  ← Cluster-wide (all namespaces)                          │
│   └─────────────────┘                                                           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Subjects: Users vs Groups vs ServiceAccounts

| Subject | Who Uses It | How It's Created | Example |
|---------|-------------|------------------|---------|
| **User** | Human operators | External IdP (AWS IAM, OIDC, certificates) | `john@company.com` |
| **Group** | Collection of users | External IdP (AWS IAM groups, OIDC groups) | `developers`, `sre-team` |
| **ServiceAccount** | Pods/Applications | Kubernetes API (`kubectl create sa`) | `api-gateway-sa` |

### Key Differences

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  USERS & GROUPS                    │  SERVICE ACCOUNTS                          │
├────────────────────────────────────┼────────────────────────────────────────────┤
│ • For human operators              │ • For pods/applications                    │
│ • Created OUTSIDE Kubernetes       │ • Created INSIDE Kubernetes                │
│ • Managed by IdP (IAM, OIDC)       │ • Managed by K8s API                       │
│ • Used with kubectl, dashboards    │ • Used by running containers               │
│ • Example: SRE accessing cluster   │ • Example: App reading ConfigMaps          │
└────────────────────────────────────┴────────────────────────────────────────────┘
```

## Role Types Explained

### Your Team Roles

| Role | Who | What They Can Do | What They Can't Do |
|------|-----|------------------|-------------------|
| **cluster-admin** | Platform leads | Everything | Nothing restricted |
| **sre** | SRE/On-call | Restart pods, exec, view secrets, scale, cordon nodes | Create namespaces, modify RBAC |
| **devops** | CI/CD engineers | Deploy, update configs, create secrets | Read secret values, access nodes |
| **developer** | App developers | View resources, exec, logs, port-forward | Modify deployments, view secrets |
| **viewer** | QA, PMs | View everything except secrets | Any modifications |
| **namespace-admin** | Team leads | Everything in their namespace | Cluster-wide resources |

### Permission Matrix

| Action | Admin | SRE | DevOps | Developer | Viewer |
|--------|-------|-----|--------|-----------|--------|
| **Deployments** |
| Create deployment | ✅ | ❌ | ✅ | ❌ | ❌ |
| Update deployment | ✅ | ✅ | ✅ | ❌ | ❌ |
| Delete deployment | ✅ | ✅ | ✅ | ❌ | ❌ |
| View deployment | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Pods** |
| View pods | ✅ | ✅ | ✅ | ✅ | ✅ |
| View logs | ✅ | ✅ | ✅ | ✅ | ✅ |
| Exec into pod | ✅ | ✅ | ❌ | ✅ | ❌ |
| Delete pod | ✅ | ✅ | ✅ | ❌ | ❌ |
| Port-forward | ✅ | ✅ | ❌ | ✅ | ❌ |
| **Secrets** |
| View secrets | ✅ | ✅ | ❌ | ❌ | ❌ |
| Create secrets | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Nodes** |
| View nodes | ✅ | ✅ | ❌ | ❌ | ❌ |
| Cordon/uncordon | ✅ | ✅ | ❌ | ❌ | ❌ |
| **ConfigMaps** |
| View | ✅ | ✅ | ✅ | ✅ | ✅ |
| Modify | ✅ | ✅ | ✅ | ❌ | ❌ |

---

## Setting Up Users with AWS EKS

Kubernetes doesn't manage users directly. With EKS, you use **AWS IAM** for authentication.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         EKS AUTHENTICATION FLOW                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐  │
│   │  User    │────►│  AWS IAM     │────►│  EKS API     │────►│  K8s RBAC    │  │
│   │ (kubectl)│     │ (Identity)   │     │ (AuthN)      │     │ (AuthZ)      │  │
│   └──────────┘     └──────────────┘     └──────────────┘     └──────────────┘  │
│                                                                                  │
│   1. User runs      2. AWS verifies    3. EKS maps IAM    4. K8s checks if     │
│      kubectl           IAM creds          to K8s user        user has perms    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Step 1: Create IAM Users/Groups in AWS

```bash
# Create IAM users for your team
aws iam create-user --user-name john-developer
aws iam create-user --user-name sarah-sre
aws iam create-user --user-name mike-devops

# Create IAM groups
aws iam create-group --group-name eks-developers
aws iam create-group --group-name eks-sre
aws iam create-group --group-name eks-devops
aws iam create-group --group-name eks-admins

# Add users to groups
aws iam add-user-to-group --user-name john-developer --group-name eks-developers
aws iam add-user-to-group --user-name sarah-sre --group-name eks-sre
aws iam add-user-to-group --user-name mike-devops --group-name eks-devops
```

### Step 2: Create IAM Policy for EKS Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

```bash
# Create and attach policy
aws iam create-policy --policy-name EKSDescribeCluster --policy-document file://eks-policy.json
aws iam attach-group-policy --group-name eks-developers --policy-arn arn:aws:iam::ACCOUNT_ID:policy/EKSDescribeCluster
aws iam attach-group-policy --group-name eks-sre --policy-arn arn:aws:iam::ACCOUNT_ID:policy/EKSDescribeCluster
```

### Step 3: Configure aws-auth ConfigMap

The `aws-auth` ConfigMap maps IAM users/roles to Kubernetes users/groups.

```bash
kubectl edit configmap aws-auth -n kube-system
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  # Node IAM role (already exists)
  mapRoles: |
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/eksctl-purely-cluster-nodegroup-NodeInstanceRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    
    # SRE team role (for assuming role)
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/EKS-SRE-Role
      username: sre-user
      groups:
        - sre-team
    
    # DevOps role
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/EKS-DevOps-Role
      username: devops-user
      groups:
        - devops-team

  # Map IAM users directly
  mapUsers: |
    # Cluster Admin
    - userarn: arn:aws:iam::ACCOUNT_ID:user/cluster-admin
      username: cluster-admin
      groups:
        - system:masters    # Built-in admin group
    
    # SRE users
    - userarn: arn:aws:iam::ACCOUNT_ID:user/sarah-sre
      username: sarah-sre
      groups:
        - sre-team
    
    # DevOps users
    - userarn: arn:aws:iam::ACCOUNT_ID:user/mike-devops
      username: mike-devops
      groups:
        - devops-team
    
    # Developer users
    - userarn: arn:aws:iam::ACCOUNT_ID:user/john-developer
      username: john-developer
      groups:
        - developers
    
    # Viewer users
    - userarn: arn:aws:iam::ACCOUNT_ID:user/qa-user
      username: qa-user
      groups:
        - viewers
```

### Step 4: Apply Kubernetes RBAC

Update your Helm values to bind the groups:

```yaml
# helm-charts/common/values.yaml
teamRBAC:
  enabled: true
  
  clusterAdmins:
    groups:
      - "system:masters"  # Maps to IAM users in system:masters
  
  sre:
    groups:
      - "sre-team"  # Maps to IAM group/users with sre-team in aws-auth
  
  devops:
    groups:
      - "devops-team"
  
  developers:
    groups:
      - "developers"
  
  viewers:
    groups:
      - "viewers"
```

```bash
# Deploy RBAC
helm upgrade --install common ./helm-charts/common -n purely
```

### Step 5: Configure kubectl for Users

Each user needs to configure their kubectl:

```bash
# User configures AWS credentials
aws configure
# Enter Access Key ID and Secret Access Key

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name purely-cluster

# Test access
kubectl get pods
```

---

## Alternative: Using IAM Roles (Recommended for AWS)

Instead of IAM users, use IAM roles with assume role. This is more secure.

### Create IAM Roles

```bash
# Create SRE role
aws iam create-role --role-name EKS-SRE-Role --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

# Create Developer role
aws iam create-role --role-name EKS-Developer-Role --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'
```

### Allow Users to Assume Roles

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::ACCOUNT_ID:role/EKS-Developer-Role"
    }
  ]
}
```

### Users Assume Role to Access Cluster

```bash
# Add role profile to ~/.aws/config
[profile eks-developer]
role_arn = arn:aws:iam::ACCOUNT_ID:role/EKS-Developer-Role
source_profile = default

# Use the role
export AWS_PROFILE=eks-developer
kubectl get pods
```

---

## Using OIDC Provider (Okta, Azure AD, etc.)

For enterprise setups, use OIDC:

```bash
# Associate OIDC provider with EKS
eksctl utils associate-iam-oidc-provider \
  --cluster purely-cluster \
  --region us-east-1 \
  --approve
```

Then configure your OIDC provider to issue tokens with group claims that map to Kubernetes groups.

---

## Verifying RBAC Permissions

### Check What You Can Do

```bash
# Check if you can get pods
kubectl auth can-i get pods
# yes

# Check if you can delete deployments
kubectl auth can-i delete deployments
# no

# Check all permissions in a namespace
kubectl auth can-i --list -n purely
```

### Check What a User Can Do (as admin)

```bash
# Check what a specific user can do
kubectl auth can-i get pods --as=john-developer
kubectl auth can-i delete deployments --as=john-developer
kubectl auth can-i get secrets --as=john-developer

# Check as a group
kubectl auth can-i delete pods --as-group=developers
```

### View Current RBAC Bindings

```bash
# List all cluster role bindings
kubectl get clusterrolebindings | grep purely

# List role bindings in namespace
kubectl get rolebindings -n purely

# Describe a specific binding
kubectl describe clusterrolebinding purely-sre-group-sre-team
```

---

## Common Use Cases

### 1. New Developer Joins Team

```bash
# 1. Create IAM user
aws iam create-user --user-name new-developer

# 2. Add to IAM group
aws iam add-user-to-group --user-name new-developer --group-name eks-developers

# 3. Update aws-auth (if using direct user mapping)
kubectl edit configmap aws-auth -n kube-system
# Add user to mapUsers with group "developers"

# 4. RBAC already handles permissions via group binding
# No K8s changes needed if group binding exists!
```

### 2. Grant Temporary Admin Access

```bash
# Create a temporary binding
kubectl create clusterrolebinding temp-admin \
  --clusterrole=purely-cluster-admin \
  --user=emergency-user@company.com

# Remove after emergency
kubectl delete clusterrolebinding temp-admin
```

### 3. Developer Needs Access to Production

```yaml
# Add namespace-specific binding in values.yaml
namespaceBindings:
  - namespace: purely-prod
    role: viewer          # Read-only in prod
    user: "john-developer"
  - namespace: purely-dev
    role: developer       # Full dev access in dev
    user: "john-developer"
```

---

## Best Practices

1. **Use Groups, Not Users** - Easier to manage at scale
2. **Least Privilege** - Start with viewer, add permissions as needed
3. **Use Roles for AWS** - More secure than IAM users
4. **Audit Regularly** - Review who has access monthly
5. **Namespace Isolation** - Give teams access only to their namespaces
6. **Don't Share Credentials** - Each person gets their own IAM identity
7. **Use MFA** - Require MFA for cluster access via IAM policies

---

## Quick Reference Commands

```bash
# View all roles
kubectl get clusterroles | grep purely

# View all bindings
kubectl get clusterrolebindings | grep purely

# Check your permissions
kubectl auth can-i --list

# Test as another user
kubectl auth can-i get pods --as=john-developer -n purely

# View aws-auth configmap
kubectl get configmap aws-auth -n kube-system -o yaml

# Apply RBAC changes
helm upgrade --install common ./helm-charts/common -n purely
```
