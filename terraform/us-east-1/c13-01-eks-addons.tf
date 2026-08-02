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
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true
}

# -----------------------------------------------------------------------------
# COREDNS ADD-ON
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-coredns"
    }
  )

  depends_on = [aws_eks_node_group.eks_ng_private]
}

# -----------------------------------------------------------------------------
# KUBE-PROXY ADD-ON
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-kube-proxy"
    }
  )

  depends_on = [aws_eks_node_group.eks_ng_private]
}

# -----------------------------------------------------------------------------
# VPC CNI ADD-ON
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-vpc-cni"
    }
  )

  depends_on = [aws_eks_node_group.eks_ng_private]
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------
output "eks_addon_coredns_version" {
  description = "CoreDNS add-on version"
  value       = aws_eks_addon.coredns.addon_version
}

output "eks_addon_kube_proxy_version" {
  description = "Kube-proxy add-on version"
  value       = aws_eks_addon.kube_proxy.addon_version
}

output "eks_addon_vpc_cni_version" {
  description = "VPC CNI add-on version"
  value       = aws_eks_addon.vpc_cni.addon_version
}
