# =============================================================================
# DEVOPS IAM ROLE & KUBERNETES RBAC
# =============================================================================
# Who: DevOps engineers, CI/CD pipelines
# What: Deploy applications, manage configs, cannot read secrets directly
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role for DevOps
# -----------------------------------------------------------------------------
resource "aws_iam_role" "eks_devops_role" {
  name = "${local.name}-eks-devops-role"

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
    name = "eks-devops-access-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "eks:DescribeCluster",
            "eks:ListClusters",
            "eks:DescribeNodegroup",
            "eks:ListNodegroups",
            "eks:AccessKubernetesApi"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload"
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
# IAM Group for DevOps
# -----------------------------------------------------------------------------
resource "aws_iam_group" "eksdevops_iam_group" {
  name = "${local.name}-eksdevops"
  path = "/"
}

# Allow DevOps group to assume the DevOps role
resource "aws_iam_group_policy" "eksdevops_iam_group_assumerole_policy" {
  name  = "${local.name}-eksdevops-group-policy"
  group = aws_iam_group.eksdevops_iam_group.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["sts:AssumeRole"]
        Effect   = "Allow"
        Sid      = "AllowAssumeEKSDevOpsRole"
        Resource = aws_iam_role.eks_devops_role.arn
      },
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM User for DevOps (Example - add more users as needed)
# -----------------------------------------------------------------------------
resource "aws_iam_user" "eksdevops_user" {
  name          = "${local.name}-eksdevops1"
  path          = "/"
  force_destroy = true
  tags          = local.common_tags
}

# Add DevOps user to DevOps group
resource "aws_iam_group_membership" "eksdevops" {
  name = "${local.name}-eksdevops-group-membership"
  users = [
    aws_iam_user.eksdevops_user.name
  ]
  group = aws_iam_group.eksdevops_iam_group.name
}

# -----------------------------------------------------------------------------
# Kubernetes ClusterRole for DevOps
# -----------------------------------------------------------------------------
resource "kubernetes_cluster_role_v1" "eksdevops_clusterrole" {
  depends_on = [aws_eks_cluster.eks_cluster]
  metadata {
    name = "${local.name}-eksdevops-clusterrole"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "devops"
    }
  }

  # Deployments - full CRUD
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Pods - view and delete (for rollouts)
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }

  # Services - full CRUD
  rule {
    api_groups = [""]
    resources  = ["services", "endpoints"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # ConfigMaps - full access
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Secrets - create/update only (for deployments), cannot read values
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "update", "patch", "delete"]
  }

  # Ingress - full CRUD
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # HPA - full CRUD
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # PDB - full CRUD
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Jobs - full CRUD
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Service Accounts (for deployments)
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["get", "list", "watch", "create"]
  }

  # Events
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }

  # Namespaces - view only
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}

# -----------------------------------------------------------------------------
# Kubernetes ClusterRoleBinding for DevOps
# -----------------------------------------------------------------------------
resource "kubernetes_cluster_role_binding_v1" "eksdevops_clusterrolebinding" {
  metadata {
    name = "${local.name}-eksdevops-clusterrolebinding"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "devops"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.eksdevops_clusterrole.metadata.0.name
  }
  subject {
    kind      = "Group"
    name      = "eks-devops-group"
    api_group = "rbac.authorization.k8s.io"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "eks_devops_role_arn" {
  description = "ARN of the EKS DevOps IAM role"
  value       = aws_iam_role.eks_devops_role.arn
}

output "eksdevops_user_arn" {
  description = "ARN of the EKS DevOps IAM user"
  value       = aws_iam_user.eksdevops_user.arn
}
