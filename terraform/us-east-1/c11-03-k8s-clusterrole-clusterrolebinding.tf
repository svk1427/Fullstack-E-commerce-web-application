# =============================================================================
# DEVELOPER CLUSTER ROLE
# =============================================================================
# Who: Application developers
# What: View resources, exec into pods, view logs, port-forward (debugging)
# Cannot: Modify deployments, view secrets, access nodes
# =============================================================================
resource "kubernetes_cluster_role_v1" "eksdeveloper_clusterrole" {
  metadata {
    name = "${local.name}-eksdeveloper-clusterrole"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "developer"
    }
  }

  # Core resources - view
  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "pods", "events", "services", "endpoints", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }
  
  # Pod logs - essential for debugging
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
  
  # Pod exec - for debugging (kubectl exec)
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }
  
  # Pod port-forward - for local testing (kubectl port-forward)
  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create"]
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
}

# Resource: k8s Cluster Role Binding
resource "kubernetes_cluster_role_binding_v1" "eksdeveloper_clusterrolebinding" {
  metadata {
    name = "${local.name}-eksdeveloper-clusterrolebinding"
    labels = {
      "app.kubernetes.io/part-of" = "purely-ecommerce"
      "rbac.purely.io/role-type"  = "developer"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.eksdeveloper_clusterrole.metadata.0.name
  }
  subject {
    kind      = "Group"
    name      = "eks-developer-group"
    api_group = "rbac.authorization.k8s.io"
  }
}