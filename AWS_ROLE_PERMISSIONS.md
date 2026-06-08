# AWS_ROLE_TO_ASSUME - Permissions Reference

## Overview
The `AWS_ROLE_TO_ASSUME` is an IAM role that GitHub Actions uses to deploy infrastructure via Terraform. This role requires specific permissions grouped by functionality.

## Setup Instructions

### 1. Create the IAM Role
```bash
aws iam create-role \
  --role-name github-actions-terraform-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          },
          "StringLike": {
            "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
          }
        }
      }
    ]
  }'
```

### 2. Attach the Policy
```bash
aws iam put-role-policy \
  --role-name github-actions-terraform-role \
  --policy-name terraform-policy \
  --policy-document file://aws-github-actions-policy.json
```

### 3. Get the Role ARN
```bash
aws iam get-role --role-name github-actions-terraform-role --query 'Role.Arn'
```
Result: `arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-terraform-role`

---

## Permissions Breakdown

### **State Management** (Required for all operations)
- `s3:GetObject` - Read Terraform state
- `s3:PutObject` - Write Terraform state
- `s3:DeleteObject` - Delete state versions
- `s3:ListBucket` - List state bucket contents
- `dynamodb:PutItem` - Create state locks
- `dynamodb:GetItem` - Read state locks
- `dynamodb:DeleteItem` - Remove state locks
- `dynamodb:DescribeTable` - Check lock table status

**Why:** Terraform needs to read and write state to S3 with DynamoDB for concurrent operation locking.

---

### **VPC Management** (Network Infrastructure)
Groups of permissions for:
- Creating/deleting VPCs and subnets
- Internet Gateway management
- NAT Gateway provisioning
- Route table configuration
- Security group rules
- Network interface modifications

**Why:** Your `vpc.tf`, `vpc-subnets.tf`, `vpc-internet-gateway.tf`, `vpc-nat-gateway.tf`, and `vpc-route-tables.tf` files create this infrastructure.

---

### **EKS Cluster Management** (Kubernetes Control Plane)
- `eks:CreateCluster` - Create EKS cluster
- `eks:DeleteCluster` - Delete cluster
- `eks:DescribeCluster` - Get cluster details
- `eks:UpdateCluster` - Modify cluster configuration
- `eks:CreateNodegroup` - Add node groups
- `eks:DeleteNodegroup` - Remove node groups
- `eks:UpdateNodegroupConfig` - Scale/update nodes

**Why:** Required by `eks-cluster.tf` and `eks-node-groups.tf` to provision Kubernetes infrastructure.

---

### **EKS Access Entries** (RBAC Management)
- `eks:CreateAccessEntry` - Create IAM access entries
- `eks:DeleteAccessEntry` - Remove access entries
- `eks:DescribeAccessEntry` - Get access entry details
- `eks:UpdateAccessEntry` - Modify access entries

**Why:** Required by `eks-access-entries.tf` for managing who can access the cluster.

---

### **EKS Add-ons** (Kubernetes Components)
- `eks:CreateAddon` - Install cluster add-ons
- `eks:DeleteAddon` - Remove add-ons
- `eks:UpdateAddon` - Update add-on versions

**Why:** Required by `eks-alb-controller.tf`, `eks-cluster-autoscaler.tf`, and `eks-metrics-server.tf`.

---

### **EC2 Management** (Compute Instances)
- `ec2:RunInstances` - Launch EC2 instances
- `ec2:TerminateInstances` - Stop/terminate instances
- `ec2:DescribeInstances` - Get instance information
- `ec2:DescribeInstanceTypes` - Check available instance types
- `ec2:DescribeImages` - Look up AMI IDs
- `ec2:*Tags` - Tag resources for organization

**Why:** EKS node groups create EC2 instances behind the scenes.

---

### **IAM Role Management** (Service Roles)
- `iam:CreateRole` - Create IAM roles
- `iam:DeleteRole` - Delete roles
- `iam:AttachRolePolicy` - Attach policies to roles
- `iam:DetachRolePolicy` - Remove policies from roles
- `iam:PutRolePolicy` - Inline policy management
- `iam:UpdateAssumeRolePolicy` - Modify trust relationships

**Why:** Your Terraform creates service roles for EKS cluster and nodes (`eks-cluster.tf`, `eks-node-groups.tf`).

---

### **IAM OIDC Provider** (Kubernetes ServiceAccount Auth)
- `iam:CreateOpenIDConnectProvider` - Create OIDC provider
- `iam:DeleteOpenIDConnectProvider` - Delete provider
- `iam:UpdateOpenIDConnectProviderThumbprint` - Update thumbprint

**Why:** Required by `eks-openid-connect-provider.tf` to enable pod IAM authentication.

---

### **ECR Repository Management** (Container Registry)
- `ecr:CreateRepository` - Create ECR repositories
- `ecr:DeleteRepository` - Delete repositories
- `ecr:DescribeRepositories` - Get repository details
- `ecr:PutImageScanningConfiguration` - Enable image scanning
- `ecr:PutLifecyclePolicy` - Set image retention policies

**Why:** Required by `ecr-registries.tf` (10 microservice registries).

---

### **Auto Scaling** (Node Group Scaling)
- `autoscaling:CreateAutoScalingGroup` - Create ASG for nodes
- `autoscaling:UpdateAutoScalingGroup` - Adjust scaling parameters
- `autoscaling:DescribeAutoScalingGroups` - Check ASG status

**Why:** EKS node groups use Auto Scaling Groups for scaling.

---

### **Launch Template Management**
- `ec2:CreateLaunchTemplate` - Create launch configurations
- `ec2:DescribeLaunchTemplates` - Get template details

**Why:** EKS uses launch templates for node provisioning.

---

### **Helper Permissions**
- `sts:GetCallerIdentity` - Verify who is making requests

**Why:** Terraform uses this to validate credentials and get account ID.

---

## Least Privilege Alternative

If you want to restrict further, use specific resource ARNs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::my-tf-state-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:*", "eks:*", "iam:*", "ecr:*"],
      "Resource": "*"
    }
  ]
}
```

---

## Testing the Role

```bash
# Test OIDC authentication (from GitHub Actions)
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform-role \
  --role-session-name github-actions \
  --web-identity-token $GITHUB_TOKEN

# Test from CLI (if role trusts your current identity)
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform-role \
  --role-session-name test-session
```

---

## Security Considerations

✅ **Use OIDC** - No long-lived AWS credentials stored in GitHub
✅ **Scope by repository** - Add condition to restrict to your repo
✅ **Scope by branch** - Add condition to restrict to specific branches (e.g., main)
✅ **Regular audit** - Review role usage in CloudTrail
✅ **Versioned policy** - Keep this policy document in version control
✅ **Test permissions** - Run `terraform plan` first before applying

---

## Troubleshooting Permission Errors

| Error | Solution |
|-------|----------|
| `UnauthorizedOperation` | Policy missing the required action |
| `AccessDenied` | Resource ARN doesn't match policy resources |
| `InvalidRole` | Role ARN incorrect or role doesn't exist |
| `AssumeRoleUnauthorizedAccess` | OIDC provider not configured or trust policy wrong |

Check CloudTrail logs:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=github-actions-terraform-role \
  --max-results 10
```
