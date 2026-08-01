# =============================================================================
# VIEWER/READONLY CLUSTER ROLE
# =============================================================================
# Who: QA, Product managers, Stakeholders
# What: View all resources except secrets (read-only access)
# =============================================================================
resource "kubernetes_cluster_role_v1" "eksreadonly_clusterrole" {
  metadata {
    name = "${local.name}-eksreadonly-clusterrole"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "viewer"
    }
  }
  
  # Core resources - view only
  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "pods", "events", "services", "endpoints", "configmaps", "persistentvolumeclaims", "serviceaccounts"]
    verbs      = ["get", "list", "watch"]
  }
  
  # Pod logs - for viewing application logs
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
  
  # Workloads - view only
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "statefulsets", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  
  # Batch jobs - view only
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch"]
  }
  
  # Networking - view only
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "watch"]
  }
  
  # Autoscaling - view only
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch"]
  }
  
  # Policy - view only
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["get", "list", "watch"]
  }
}

# Resource: Cluster Role Binding
resource "kubernetes_cluster_role_binding_v1" "eksreadonly_clusterrolebinding" {
  metadata {
    name = "${local.name}-eksreadonly-clusterrolebinding"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "viewer"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.eksreadonly_clusterrole.metadata.0.name
  }
  subject {
    kind      = "Group"
    name      = "eks-readonly-group"
    api_group = "rbac.authorization.k8s.io"
  }
}
 