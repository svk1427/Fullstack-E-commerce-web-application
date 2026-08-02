# =============================================================================
# SRE (SITE RELIABILITY ENGINEER) IAM ROLE & KUBERNETES RBAC
# =============================================================================
# Who: SRE team, On-call engineers
# What: Operations access - restart pods, exec, view secrets, scale, cordon nodes
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role for SRE
# -----------------------------------------------------------------------------
resource "aws_iam_role" "eks_sre_role" {
  name = "${local.name}-eks-sre-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })

  inline_policy {
    name = "eks-sre-access-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "eks:DescribeCluster",
            "eks:ListClusters",
            "eks:DescribeNodegroup",
            "eks:ListNodegroups",
            "eks:DescribeUpdate",
            "eks:AccessKubernetesApi"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM Group for SRE
# -----------------------------------------------------------------------------
resource "aws_iam_group" "ekssre_iam_group" {
  name = "${local.name}-ekssre"
  path = "/"
}

# Allow SRE group to assume the SRE role
resource "aws_iam_group_policy" "ekssre_iam_group_assumerole_policy" {
  name  = "${local.name}-ekssre-group-policy"
  group = aws_iam_group.ekssre_iam_group.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["sts:AssumeRole"]
        Effect   = "Allow"
        Sid      = "AllowAssumeEKSSRERole"
        Resource = aws_iam_role.eks_sre_role.arn
      },
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM User for SRE (Example - add more users as needed)
# -----------------------------------------------------------------------------
resource "aws_iam_user" "ekssre_user" {
  name          = "${local.name}-ekssre1"
  path          = "/"
  force_destroy = true
  tags          = local.common_tags
}

# Add SRE user to SRE group
resource "aws_iam_group_membership" "ekssre" {
  name = "${local.name}-ekssre-group-membership"
  users = [
    aws_iam_user.ekssre_user.name
  ]
  group = aws_iam_group.ekssre_iam_group.name
}

# -----------------------------------------------------------------------------
# Kubernetes ClusterRole for SRE
# -----------------------------------------------------------------------------
resource "kubernetes_cluster_role_v1" "ekssre_clusterrole" {
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_ng_private
  ]
  metadata {
    name = "${local.name}-ekssre-clusterrole"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "sre"
    }
  }

  # Full access to workloads (deployments, statefulsets, etc.)
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "update", "patch", "delete"]
  }

  # Full pod access (restart, exec, logs)
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log", "pods/exec", "pods/portforward"]
    verbs      = ["get", "list", "create"]
  }

  # Services and networking
  rule {
    api_groups = [""]
    resources  = ["services", "endpoints"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  # ConfigMaps and Secrets (for troubleshooting)
  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  # Events (for troubleshooting)
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }

  # Node access (view, cordon/uncordon)
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }

  # Namespaces
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  # PVCs
  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "update", "patch", "delete"]
  }

  # HPA and scaling
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  # Jobs and CronJobs
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # RBAC (view only)
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch"]
  }
}

# -----------------------------------------------------------------------------
# Kubernetes ClusterRoleBinding for SRE
# -----------------------------------------------------------------------------
resource "kubernetes_cluster_role_binding_v1" "ekssre_clusterrolebinding" {
  metadata {
    name = "${local.name}-ekssre-clusterrolebinding"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "sre"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.ekssre_clusterrole.metadata.0.name
  }
  subject {
    kind      = "Group"
    name      = "eks-sre-group"
    api_group = "rbac.authorization.k8s.io"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "eks_sre_role_arn" {
  description = "ARN of the EKS SRE IAM role"
  value       = aws_iam_role.eks_sre_role.arn
}

output "ekssre_user_arn" {
  description = "ARN of the EKS SRE IAM user"
  value       = aws_iam_user.ekssre_user.arn
}
