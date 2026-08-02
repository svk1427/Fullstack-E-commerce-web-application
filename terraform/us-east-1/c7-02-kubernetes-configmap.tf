# Get AWS Account ID
data "aws_caller_identity" "current" {}
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

# =============================================================================
# AWS-AUTH CONFIGMAP
# =============================================================================
# This ConfigMap controls who can access the EKS cluster
# IMPORTANT: This must be created BEFORE any other Kubernetes resources
# to allow nodes to join and Terraform to manage the cluster
# =============================================================================

# Locals Block - Define roles and users for aws-auth
locals {
  # Core roles needed for cluster operation
  configmap_roles = [
    # Node role - REQUIRED for worker nodes to join the cluster
    {
      rolearn  = aws_iam_role.eks_nodegroup_role.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
    # Admin role - Full cluster access
    {
      rolearn  = aws_iam_role.eks_admin_role.arn
      username = "eks-admin"
      groups   = ["system:masters"]
    },
    # Read-only role
    {
      rolearn  = aws_iam_role.eks_readonly_role.arn
      username = "eks-readonly"
      groups   = ["eks-readonly-group"]
    },
    # Developer role
    {
      rolearn  = aws_iam_role.eks_developer_role.arn
      username = "eks-developer"
      groups   = ["eks-developer-group"]
    },
    # SRE Role - Operations and troubleshooting access
    {
      rolearn  = aws_iam_role.eks_sre_role.arn
      username = "eks-sre"
      groups   = ["eks-sre-group"]
    },
    # DevOps Role - CI/CD and deployment access
    {
      rolearn  = aws_iam_role.eks_devops_role.arn
      username = "eks-devops"
      groups   = ["eks-devops-group"]
    },
  ]
  
  configmap_users = [
    {
      userarn  = aws_iam_user.basic_user.arn
      username = aws_iam_user.basic_user.name
      groups   = ["system:masters"]
    },
    {
      userarn  = aws_iam_user.admin_user.arn
      username = aws_iam_user.admin_user.name
      groups   = ["system:masters"]
    },
  ]
}

# Resource: Kubernetes Config Map
# NOTE: This only depends on the EKS cluster, NOT on Kubernetes RBAC resources
# This breaks the circular dependency that was causing "Unauthorized" errors
resource "kubernetes_config_map_v1" "aws_auth" {
  depends_on = [aws_eks_cluster.eks_cluster]
  
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = yamlencode(local.configmap_roles)
    mapUsers = yamlencode(local.configmap_users)
  }
}

