# =============================================================================
# EKS ADD-ONS (MANAGED BY AWS)
# =============================================================================
# These add-ons are managed by AWS EKS and visible in AWS Console
# Benefits: Auto-updates, AWS support, consistent versioning
# =============================================================================

# -----------------------------------------------------------------------------
# DATA SOURCE: Get latest add-on versions
# -----------------------------------------------------------------------------
data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.purely_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.purely_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.purely_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "eks_pod_identity_agent" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = aws_eks_cluster.purely_cluster.version
  most_recent        = true
}

# -----------------------------------------------------------------------------
# COREDNS ADD-ON
# -----------------------------------------------------------------------------
# Provides DNS resolution for service discovery within the cluster
# All pods use CoreDNS to resolve service names (e.g., auth-svc → 10.0.1.15)
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.purely_cluster.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    replicaCount = 2
    resources = {
      limits = {
        cpu    = "100m"
        memory = "150Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "70Mi"
      }
    }
  })

  tags = {
    Name        = "${var.project_name}-coredns"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_eks_node_group.purely_node_group]
}

# -----------------------------------------------------------------------------
# KUBE-PROXY ADD-ON
# -----------------------------------------------------------------------------
# Manages network rules on each node for Service routing
# Enables ClusterIP and NodePort services to work
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.purely_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name        = "${var.project_name}-kube-proxy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_eks_node_group.purely_node_group]
}

# -----------------------------------------------------------------------------
# VPC CNI ADD-ON
# -----------------------------------------------------------------------------
# Provides pod networking using AWS VPC native networking
# Each pod gets an IP address from the VPC subnet
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.purely_cluster.name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni_role.arn

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  tags = {
    Name        = "${var.project_name}-vpc-cni"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_eks_node_group.purely_node_group]
}

# -----------------------------------------------------------------------------
# EKS POD IDENTITY AGENT ADD-ON
# -----------------------------------------------------------------------------
# Enables IAM roles for service accounts (IRSA) - pods can assume AWS roles
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name                = aws_eks_cluster.purely_cluster.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = data.aws_eks_addon_version.eks_pod_identity_agent.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name        = "${var.project_name}-pod-identity-agent"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_eks_node_group.purely_node_group]
}

# -----------------------------------------------------------------------------
# VPC CNI IAM ROLE (for IRSA)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "vpc_cni_role" {
  name = "${var.project_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks_oidc.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
          "${replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-vpc-cni-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni_role.name
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------
output "eks_addons" {
  description = "EKS managed add-ons"
  value = {
    coredns              = aws_eks_addon.coredns.addon_version
    kube_proxy           = aws_eks_addon.kube_proxy.addon_version
    vpc_cni              = aws_eks_addon.vpc_cni.addon_version
    pod_identity_agent   = aws_eks_addon.eks_pod_identity_agent.addon_version
  }
}
