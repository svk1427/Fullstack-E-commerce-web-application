# Resource: k8s namespace
resource "kubernetes_namespace_v1" "k8s_dev" {
  depends_on = [aws_eks_cluster.eks_cluster]
  metadata {
    name = "dev"
  }
}