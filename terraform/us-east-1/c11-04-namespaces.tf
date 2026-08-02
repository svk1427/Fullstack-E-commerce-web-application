# Resource: k8s namespace
resource "kubernetes_namespace_v1" "k8s_dev" {
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_ng_private
  ]
  metadata {
    name = "dev"
  }
}