# =============================================================================
# CLUSTER AUTOSCALER - AUTO-SCALES EC2 NODES
# =============================================================================
# Automatically adds/removes EC2 nodes based on pod scheduling needs
# - Scales UP when pods are Pending (no node has enough resources)
# - Scales DOWN when nodes are underutilized
# =============================================================================

# -----------------------------------------------------------------------------
# IAM ROLE FOR CLUSTER AUTOSCALER (IRSA)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "cluster_autoscaler_role" {
  name = "${local.name}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.oidc_provider.arn
      }
      Condition = {
        StringEquals = {
          "${local.aws_iam_oidc_connect_provider_extract_from_arn}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
          "${local.aws_iam_oidc_connect_provider_extract_from_arn}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-cluster-autoscaler-role"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM POLICY FOR CLUSTER AUTOSCALER
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name        = "${local.name}-cluster-autoscaler-policy"
  description = "Policy for Cluster Autoscaler to manage ASG"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"                            = "true"
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${local.eks_cluster_name}"          = "owned"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-cluster-autoscaler-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
  role       = aws_iam_role.cluster_autoscaler_role.name
}

# -----------------------------------------------------------------------------
# CLUSTER AUTOSCALER HELM RELEASE
# -----------------------------------------------------------------------------
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.35.0"

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = aws_eks_cluster.eks_cluster.name
      }
      awsRegion = var.aws_region
      rbac = {
        serviceAccount = {
          create = true
          name   = "cluster-autoscaler"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler_role.arn
          }
        }
      }
      extraArgs = {
        "balance-similar-node-groups"    = true
        "skip-nodes-with-system-pods"    = false
        "scale-down-enabled"             = true
        "scale-down-delay-after-add"     = "5m"
        "scale-down-delay-after-delete"  = "1m"
        "scale-down-unneeded-time"       = "5m"
        "scale-down-utilization-threshold" = "0.5"
        "expander"                       = "least-waste"
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.eks_ng_public,
    aws_iam_role_policy_attachment.cluster_autoscaler_attach
  ]
}

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------
output "cluster_autoscaler_role_arn" {
  description = "IAM Role ARN for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler_role.arn
}
