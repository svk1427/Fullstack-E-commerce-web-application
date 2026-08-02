# =============================================================================
# EKS NODE GROUP - PUBLIC (DISABLED FOR SECURITY)
# =============================================================================
# SECURITY NOTE: Worker nodes should NOT be in public subnets!
# This file is kept for reference but commented out.
# Use c5-08-eks-node-group-private.tf for production workloads.
# =============================================================================

# # Create AWS EKS Node Group - Public
# resource "aws_eks_node_group" "eks_ng_public" {
#   cluster_name = aws_eks_cluster.eks_cluster.name
# 
#   node_group_name = "${local.name}-eks-ng-public"
#   node_role_arn   = aws_iam_role.eks_nodegroup_role.arn
#   subnet_ids      = module.vpc.public_subnets
#   version         = var.cluster_version #(Optional: Defaults to EKS Cluster Kubernetes version)    
# 
#   ami_type       = "AL2023_x86_64_STANDARD"
#   capacity_type  = "ON_DEMAND"
#   disk_size      = 20
#   instance_types = ["t3.medium"]
# 
# 
#   remote_access {
#     ec2_ssh_key               = "vamsiacc"
#     source_security_group_ids = [module.public_bastion_sg.security_group_id]
#   }
# 
#   # =============================================================================
#   # SCALING CONFIG - Used by Cluster Autoscaler
#   # =============================================================================
#   # min_size: Minimum nodes (Autoscaler will never scale below this)
#   # max_size: Maximum nodes (Autoscaler will never scale above this)
#   # desired_size: Initial number of nodes
#   # =============================================================================
#   scaling_config {
#     desired_size = 1
#     min_size     = 1
#     max_size     = 4    # Cluster Autoscaler can scale up to 4 nodes
#   }
# 
#   # Desired max percentage of unavailable worker nodes during node group update.
#   update_config {
#     max_unavailable = 1
#     #max_unavailable_percentage = 50    # ANY ONE TO USE
#   }
# 
#   # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
#   # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
#   depends_on = [
#     aws_iam_role_policy_attachment.eks-AmazonEKSWorkerNodePolicy,
#     aws_iam_role_policy_attachment.eks-AmazonEKS_CNI_Policy,
#     aws_iam_role_policy_attachment.eks-AmazonEC2ContainerRegistryReadOnly,
#     kubernetes_config_map_v1.aws_auth,
#     aws_security_group.eks_nodes_sg
#   ]
# 
#   # =============================================================================
#   # REQUIRED TAGS FOR CLUSTER AUTOSCALER
#   # =============================================================================
#   # These tags allow Cluster Autoscaler to discover and manage the node group
#   # =============================================================================
#   tags = merge(
#     local.common_tags,
#     {
#       Name                                                  = "Public-Node-Group"
#       "k8s.io/cluster-autoscaler/enabled"                   = "true"
#       "k8s.io/cluster-autoscaler/${local.eks_cluster_name}" = "owned"
#     }
#   )
# }
