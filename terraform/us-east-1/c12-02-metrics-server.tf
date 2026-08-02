# =============================================================================
# METRICS SERVER - REQUIRED FOR HPA
# =============================================================================
# Collects CPU/Memory metrics from kubelets
# HPA uses these metrics to make scaling decisions
# =============================================================================

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.0"

  values = [
    yamlencode({
      args = [
        "--kubelet-insecure-tls",
        "--kubelet-preferred-address-types=InternalIP"
      ]
      resources = {
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.eks_ng_private
  ]
}

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
output "metrics_server_status" {
  description = "Metrics Server deployment status"
  value       = helm_release.metrics_server.status
}
