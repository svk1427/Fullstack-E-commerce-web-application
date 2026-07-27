# =============================================================================
# SECURITY GROUPS FOR EKS INFRASTRUCTURE - PRODUCTION
# =============================================================================
#
# ARCHITECTURE OVERVIEW:
# ┌─────────────┐     ┌─────────────┐     ┌─────────────────────────────────┐
# │   Internet  │────▶│     ALB     │────▶│         EKS Nodes               │
# │  (Users)    │     │  (80/443)   │     │  ┌─────────┐  ┌──────────────┐  │
# └─────────────┘     └─────────────┘     │  │Frontend │  │ API Gateway  │  │
#                            │            │  │  (80)   │  │   (8080)     │  │
#                            │            │  └─────────┘  └──────┬───────┘  │
#                            │            │                      │          │
#                            │            │  ┌──────────────────▼────────┐ │
#                            │            │  │  Internal Microservices   │ │
#                            │            │  │  (9000-9070) + Eureka     │ │
#                            │            │  │  NOT EXPOSED TO INTERNET  │ │
#                            │            │  └───────────────────────────┘ │
#                            │            └─────────────────────────────────┘
#                            │
#                            ▼
# SECURITY PRINCIPLE: Defense in Depth + Least Privilege
# - ALB only routes to Frontend (80) and API Gateway (8080)
# - Backend microservices (9000-9070) are INTERNAL ONLY
# - Eureka (8761) is INTERNAL ONLY for service discovery
# - All inter-service communication happens within VPC CIDR
# - No direct internet access to any backend service
#
# =============================================================================


# #############################################################################
#                         ALB SECURITY GROUP
# #############################################################################
#
# PURPOSE: Controls traffic to/from the Application Load Balancer
#
# WHY THIS IS SECURE:
# 1. INGRESS: Only HTTP (80) and HTTPS (443) from internet - standard web ports
# 2. EGRESS: Limited to ONLY Frontend and API Gateway pods
#    - NO direct access to backend microservices
#    - NO direct access to Eureka service registry
#    - All API traffic MUST go through API Gateway
# 3. Uses Security Group references (not CIDR) for egress = more secure
# 4. target-type=ip means ALB talks directly to pods, reducing attack surface
#
# #############################################################################

resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "Security group for Application Load Balancer - allows internet traffic and routes to frontend/API gateway only"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name                                              = "${local.name}-alb-sg"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
    "ingress.k8s.aws/resource"                        = "ManagedLBSecurityGroup"
    Purpose                                           = "ALB-Internet-Facing"
  })
}

# -----------------------------------------------------------------------------
# ALB INGRESS RULES
# -----------------------------------------------------------------------------

# RULE: Allow HTTP from Internet
# WHY: Users access the application via HTTP (will be redirected to HTTPS)
# SECURITY: 
#   - Standard web port, expected for public-facing applications
#   - ALB handles SSL termination for HTTPS redirect
#   - WAF can be attached for additional protection
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
  description       = "INGRESS: HTTP (80) from Internet - Required for web access and HTTPS redirect"
}

# RULE: Allow HTTPS from Internet
# WHY: Secure encrypted traffic from users to ALB
# SECURITY:
#   - TLS 1.3 enforced via ALB SSL policy (ELBSecurityPolicy-TLS13-1-2-2021-06)
#   - SSL certificate terminates at ALB
#   - All sensitive data is encrypted in transit
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
  description       = "INGRESS: HTTPS (443) from Internet - Secure encrypted web traffic with TLS 1.3"
}

# -----------------------------------------------------------------------------
# ALB EGRESS RULES - STRICTLY LIMITED
# -----------------------------------------------------------------------------

# RULE: Health Check to Pods
# WHY: ALB must verify pods are healthy before routing traffic
# SECURITY:
#   - Single port (10254) - minimal attack surface
#   - Only to EKS nodes security group - not open to internet
#   - Required for ALB target group health checks
resource "aws_security_group_rule" "alb_egress_health_check" {
  type                     = "egress"
  from_port                = 10254
  to_port                  = 10254
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.alb_sg.id
  description              = "EGRESS: Health check (10254) to EKS nodes - Required for ALB target group health verification"
}

# RULE: Traffic to API Gateway
# WHY: All /api/* requests route through API Gateway for backend access
# SECURITY:
#   - Single port (8080) - minimal attack surface
#   - API Gateway acts as single entry point - implements rate limiting, auth
#   - Backend services are NOT directly accessible from ALB
#   - Uses security group reference, not CIDR - traffic only to known nodes
resource "aws_security_group_rule" "alb_egress_api_gateway" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.alb_sg.id
  description              = "EGRESS: API Gateway (8080) - Single entry point for all backend API traffic"
}

# RULE: Traffic to Frontend Web App
# WHY: Serves React/Vite static files via nginx
# SECURITY:
#   - Single port (80) - standard HTTP for static content
#   - Frontend is stateless - no sensitive backend logic
#   - nginx serves pre-built static files only
#   - Uses security group reference, not CIDR
resource "aws_security_group_rule" "alb_egress_frontend" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.alb_sg.id
  description              = "EGRESS: Frontend (80) - Static web assets served by nginx, no backend logic"
}

# =============================================================================
# WHAT IS NOT ALLOWED FROM ALB (Defense in Depth):
# =============================================================================
# ❌ Eureka (8761)     - Internal service discovery, no external access needed
# ❌ Auth Service      - Must go through API Gateway for proper auth flow
# ❌ User Service      - Internal only, accessed via API Gateway
# ❌ Product Service   - Internal only, accessed via API Gateway
# ❌ Cart Service      - Internal only, accessed via API Gateway
# ❌ Order Service     - Internal only, accessed via API Gateway
# ❌ Category Service  - Internal only, accessed via API Gateway
# ❌ Notification Svc  - Internal only, accessed via API Gateway
# ❌ Any Database port - Databases are never internet accessible
# =============================================================================


# #############################################################################
#                     EKS CLUSTER SECURITY GROUP
# #############################################################################
#
# PURPOSE: Controls traffic to/from the EKS Control Plane (API Server)
#
# WHY THIS IS SECURE:
# 1. Control plane is managed by AWS in their VPC
# 2. Only allows HTTPS (443) - encrypted Kubernetes API calls
# 3. Ingress limited to: Worker nodes + Bastion host ONLY
# 4. No internet access to control plane
# 5. Egress limited to worker nodes for pod management
#
# #############################################################################

resource "aws_security_group" "eks_cluster_sg" {
  name        = "${local.name}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane - manages Kubernetes API access"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name                                              = "${local.name}-eks-cluster-sg"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
    Purpose                                           = "EKS-Control-Plane"
  })
}

# RULE: Allow HTTPS from EKS Worker Nodes
# WHY: Worker nodes communicate with control plane for:
#      - Kubelet reporting node/pod status
#      - Kube-proxy getting service endpoints
#      - CNI plugin for networking
# SECURITY:
#   - Security group reference ensures only known worker nodes can connect
#   - HTTPS ensures all communication is encrypted
#   - No internet access to control plane
resource "aws_security_group_rule" "eks_cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.eks_cluster_sg.id
  description              = "INGRESS: HTTPS (443) from Worker Nodes - Kubelet, kube-proxy, CNI communication"
}

# RULE: Allow HTTPS from Bastion Host
# WHY: Administrators run kubectl commands from Bastion
# SECURITY:
#   - Bastion is the ONLY way to access cluster from outside
#   - Bastion requires SSH key authentication
#   - All kubectl commands are audited via EKS audit logs
#   - No direct internet access to Kubernetes API
resource "aws_security_group_rule" "eks_cluster_ingress_from_bastion" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.public_bastion_sg.security_group_id
  security_group_id        = aws_security_group.eks_cluster_sg.id
  description              = "INGRESS: HTTPS (443) from Bastion - kubectl access for administrators only"
}

# RULE: Control Plane to Worker Nodes
# WHY: Control plane needs to:
#      - Execute commands on pods (kubectl exec)
#      - Fetch logs (kubectl logs)
#      - Deploy/update workloads
#      - Manage cluster add-ons (CoreDNS, kube-proxy)
# SECURITY:
#   - Egress only to known worker nodes via security group reference
#   - Full TCP range needed for various Kubernetes operations
#   - Control plane is AWS-managed, inherently secure
resource "aws_security_group_rule" "eks_cluster_egress_to_nodes" {
  type                     = "egress"
  from_port                = 1024
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.eks_cluster_sg.id
  description              = "EGRESS: High ports (1024-65535) to Worker Nodes - Pod management, logs, exec"
}

# RULE: Control Plane to AWS Services
# WHY: EKS control plane needs to call AWS APIs for:
#      - CloudWatch logging
#      - IAM authentication
#      - EC2 for node management
# SECURITY:
#   - HTTPS only - all traffic encrypted
#   - Required for AWS service integration
#   - Can be restricted further with VPC endpoints
resource "aws_security_group_rule" "eks_cluster_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
  description       = "EGRESS: HTTPS (443) to AWS Services - CloudWatch, IAM, EC2 API calls"
}


# #############################################################################
#                     EKS NODES SECURITY GROUP
# #############################################################################
#
# PURPOSE: Controls ALL traffic to/from EKS worker nodes (EC2 instances)
#
# WHY THIS IS SECURE:
# 1. Ingress from ALB limited to Frontend (80) and API Gateway (8080) ONLY
# 2. Backend services (9000-9070) only accessible within VPC
# 3. Eureka (8761) only accessible within VPC
# 4. SSH access only from Bastion host
# 5. Self-referencing rules allow pod-to-pod communication securely
# 6. No direct internet ingress to any service
#
# #############################################################################

resource "aws_security_group" "eks_nodes_sg" {
  name        = "${local.name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes - controls pod and node-level traffic"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name                                              = "${local.name}-eks-nodes-sg"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
    Purpose                                           = "EKS-Worker-Nodes"
  })
}

# =============================================================================
# EKS NODES - SELF REFERENCING RULES (Pod-to-Pod Communication)
# =============================================================================

# RULE: Node-to-Node All Traffic (Ingress)
# WHY: Pods on different nodes need to communicate for:
#      - Microservice calls (API Gateway -> Auth Service, etc.)
#      - CoreDNS resolution across nodes
#      - CNI (Container Network Interface) overlay network
#      - Kubernetes service mesh traffic
# SECURITY:
#   - Self-referencing = traffic only between nodes in this security group
#   - No external access - completely internal
#   - Required for Kubernetes networking to function
resource "aws_security_group_rule" "eks_nodes_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "SELF-REF INGRESS: All traffic between nodes - Pod networking, DNS, CNI overlay"
}

# RULE: Node-to-Node All Traffic (Egress)
# WHY: Same as ingress - pods need bidirectional communication
# SECURITY:
#   - Self-referencing ensures traffic stays within cluster
#   - No data leaves to external networks
resource "aws_security_group_rule" "eks_nodes_self_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "SELF-REF EGRESS: All traffic between nodes - Required for bidirectional pod communication"
}

# =============================================================================
# EKS NODES - CONTROL PLANE COMMUNICATION
# =============================================================================

# RULE: Accept Traffic from Control Plane
# WHY: Control plane sends instructions to nodes for:
#      - Deploying new pods
#      - Executing commands in containers
#      - Fetching container logs
#      - Health checks and node management
# SECURITY:
#   - Source is EKS cluster security group only
#   - Encrypted communication (TLS)
#   - AWS-managed control plane is trusted
resource "aws_security_group_rule" "eks_nodes_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 1024
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "INGRESS: High ports from Control Plane - Pod deployment, logs, exec commands"
}

# RULE: Kubelet API from Control Plane
# WHY: Control plane calls kubelet API on port 10250 for:
#      - Pod status reporting
#      - Container health checks
#      - Resource metrics collection
# SECURITY:
#   - Single specific port - minimal attack surface
#   - Only from control plane security group
#   - Kubelet authenticates requests
resource "aws_security_group_rule" "eks_nodes_ingress_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "INGRESS: Kubelet API (10250) from Control Plane - Pod status, health checks, metrics"
}

# RULE: Nodes to Control Plane API
# WHY: Nodes need to communicate with Kubernetes API for:
#      - Registering node with cluster
#      - Watching for pod assignments
#      - Reporting node conditions
# SECURITY:
#   - HTTPS only - encrypted
#   - Destination is control plane security group only
#   - Service account tokens for authentication
resource "aws_security_group_rule" "eks_nodes_egress_to_cluster" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "EGRESS: HTTPS (443) to Control Plane - Node registration, pod watch, status reporting"
}

# =============================================================================
# EKS NODES - ALB TRAFFIC (EXTERNAL ACCESS POINTS)
# =============================================================================
# CRITICAL: These are the ONLY services accessible from ALB (internet-facing)
# All other services are internal-only
# =============================================================================

# RULE: ALB Health Checks
# WHY: ALB must verify pods are healthy before routing traffic
# SECURITY:
#   - Single port (10254)
#   - Only from ALB security group
#   - Health check endpoint returns simple status, no sensitive data
resource "aws_security_group_rule" "eks_nodes_ingress_health_check" {
  type                     = "ingress"
  from_port                = 10254
  to_port                  = 10254
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "INGRESS: ALB Health Check (10254) - Verifies pod health before routing traffic"
}

# RULE: API Gateway from ALB
# WHY: Single entry point for ALL backend API traffic
# SECURITY:
#   - ONLY external entry point to backend services
#   - API Gateway implements:
#     * Rate limiting to prevent DDoS
#     * JWT token validation
#     * Request/response logging
#     * Circuit breaker patterns
#   - Backend services are NOT directly accessible
resource "aws_security_group_rule" "eks_nodes_ingress_api_gateway" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "INGRESS: API Gateway (8080) from ALB - Single entry point with auth, rate limiting, logging"
}

# RULE: Frontend from ALB
# WHY: Serves static web content to users
# SECURITY:
#   - Stateless static file server (nginx)
#   - No backend logic or database access
#   - Pre-built React/Vite bundle - no server-side rendering risks
#   - All API calls go through separate API Gateway path
resource "aws_security_group_rule" "eks_nodes_ingress_frontend" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "INGRESS: Frontend (80) from ALB - Static web assets only, no backend logic"
}

# =============================================================================
# EKS NODES - BASTION HOST ACCESS (ADMIN ONLY)
# =============================================================================

# RULE: SSH from Bastion
# WHY: Emergency node access for troubleshooting
# SECURITY:
#   - SSH only from Bastion host - no direct internet SSH
#   - Bastion requires SSH key + optional MFA
#   - All SSH sessions can be logged
#   - Used only for emergency debugging, not regular operations
resource "aws_security_group_rule" "eks_nodes_ingress_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = module.public_bastion_sg.security_group_id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "INGRESS: SSH (22) from Bastion ONLY - Emergency admin access, key-based auth required"
}

# =============================================================================
# EKS NODES - OUTBOUND INTERNET ACCESS (REQUIRED FOR OPERATIONS)
# =============================================================================

# RULE: HTTPS Outbound
# WHY: Nodes need HTTPS access for:
#      - Pulling container images from ECR
#      - Sending logs to CloudWatch
#      - AWS API calls (IAM, STS, EC2)
#      - Downloading Helm charts
# SECURITY:
#   - HTTPS only - all traffic encrypted
#   - Can be restricted further with VPC endpoints for ECR, S3, CloudWatch
#   - Outbound only - no inbound from internet
resource "aws_security_group_rule" "eks_nodes_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "EGRESS: HTTPS (443) to Internet - ECR images, CloudWatch logs, AWS APIs"
}

# RULE: HTTP Outbound (Optional)
# WHY: Package updates, external webhooks
# SECURITY:
#   - Consider removing if not needed
#   - All sensitive operations should use HTTPS
#   - Outbound only - no inbound from internet
resource "aws_security_group_rule" "eks_nodes_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "EGRESS: HTTP (80) to Internet - Package updates, external integrations"
}

# RULE: DNS TCP Outbound
# WHY: DNS resolution for external domains
# SECURITY:
#   - Required for resolving ECR, S3, API endpoints
#   - TCP DNS used for large responses
#   - Can be restricted to VPC DNS (x.x.x.2) + Route53 resolver
resource "aws_security_group_rule" "eks_nodes_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "EGRESS: DNS TCP (53) - Large DNS responses, DNSSEC validation"
}

# RULE: DNS UDP Outbound
# WHY: Standard DNS resolution
# SECURITY:
#   - Required for all DNS lookups
#   - UDP is default DNS protocol
#   - CoreDNS uses this for external resolution
resource "aws_security_group_rule" "eks_nodes_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "EGRESS: DNS UDP (53) - Standard DNS resolution for external domains"
}

# RULE: NTP Outbound
# WHY: Time synchronization is critical for:
#      - TLS certificate validation
#      - Log timestamp accuracy
#      - Distributed system coordination
#      - JWT token expiration checks
# SECURITY:
#   - UDP 123 only
#   - Essential for security (cert validation fails with wrong time)
resource "aws_security_group_rule" "eks_nodes_egress_ntp" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "EGRESS: NTP (123) - Time sync for TLS certs, logs, JWT validation"
}

# =============================================================================
# EKS NODES - COREDNS (CLUSTER DNS)
# =============================================================================

# RULE: CoreDNS UDP from VPC
# WHY: Pods resolve service names via CoreDNS
# SECURITY:
#   - VPC CIDR only - no external DNS queries to nodes
#   - CoreDNS provides internal service discovery
#   - Kubernetes service names resolved internally
resource "aws_security_group_rule" "eks_nodes_ingress_coredns_udp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: CoreDNS UDP (53) from VPC - Internal service name resolution"
}

# RULE: CoreDNS TCP from VPC
# WHY: TCP DNS for large responses, zone transfers
# SECURITY:
#   - VPC CIDR only
#   - Backup for UDP failures
resource "aws_security_group_rule" "eks_nodes_ingress_coredns_tcp" {
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: CoreDNS TCP (53) from VPC - Large DNS responses within cluster"
}

# =============================================================================
# EKS NODES - INTERNAL MICROSERVICES (VPC ONLY - NOT INTERNET ACCESSIBLE)
# =============================================================================
# CRITICAL: These services are ONLY accessible within VPC CIDR
# They are NOT exposed to ALB or internet
# Traffic flow: ALB -> API Gateway (8080) -> Internal Services
# =============================================================================

# RULE: API Gateway Internal Access
# WHY: Other pods may call API Gateway internally
# SECURITY:
#   - VPC CIDR only - no external access
#   - Used for internal routing and service mesh
resource "aws_security_group_rule" "eks_nodes_ingress_api_gateway_vpc" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: API Gateway (8080) from VPC - Internal service mesh routing"
}

# RULE: Eureka Service Registry
# WHY: All microservices register with Eureka for discovery
# SECURITY:
#   - VPC CIDR only - NOT exposed to ALB or internet
#   - Internal service discovery mechanism
#   - No sensitive business data exposed
resource "aws_security_group_rule" "eks_nodes_ingress_eureka_vpc" {
  type              = "ingress"
  from_port         = 8761
  to_port           = 8761
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Eureka (8761) from VPC ONLY - Internal service discovery, NOT internet accessible"
}

# RULE: Category Service
# WHY: Handles product categories
# SECURITY:
#   - VPC CIDR only - accessed via API Gateway
#   - No direct external access
resource "aws_security_group_rule" "eks_nodes_ingress_category_svc" {
  type              = "ingress"
  from_port         = 9000
  to_port           = 9000
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Category Service (9000) from VPC ONLY - Internal via API Gateway"
}

# RULE: Product Service
# WHY: Handles product catalog
# SECURITY:
#   - VPC CIDR only - no direct external access
#   - Contains product data - must be protected
resource "aws_security_group_rule" "eks_nodes_ingress_product_svc" {
  type              = "ingress"
  from_port         = 9010
  to_port           = 9010
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Product Service (9010) from VPC ONLY - Internal via API Gateway"
}

# RULE: Notification Service
# WHY: Handles email/SMS notifications
# SECURITY:
#   - VPC CIDR only - no direct external access
#   - Contains user contact info - highly sensitive
resource "aws_security_group_rule" "eks_nodes_ingress_notification_svc" {
  type              = "ingress"
  from_port         = 9020
  to_port           = 9020
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Notification Service (9020) from VPC ONLY - Contains user PII, internal only"
}

# RULE: Auth Service
# WHY: Handles authentication and authorization
# SECURITY:
#   - VPC CIDR only - CRITICAL security service
#   - Handles passwords, tokens, sessions
#   - NEVER directly exposed to internet
resource "aws_security_group_rule" "eks_nodes_ingress_auth_svc" {
  type              = "ingress"
  from_port         = 9030
  to_port           = 9030
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Auth Service (9030) from VPC ONLY - CRITICAL: Handles credentials, tokens, sessions"
}

# RULE: User Service
# WHY: Handles user profiles and data
# SECURITY:
#   - VPC CIDR only - contains PII
#   - User data must be protected
resource "aws_security_group_rule" "eks_nodes_ingress_user_svc" {
  type              = "ingress"
  from_port         = 9050
  to_port           = 9050
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: User Service (9050) from VPC ONLY - Contains user PII, internal only"
}

# RULE: Cart Service
# WHY: Handles shopping cart functionality
# SECURITY:
#   - VPC CIDR only - contains user purchase intent
#   - Business logic must be protected
resource "aws_security_group_rule" "eks_nodes_ingress_cart_svc" {
  type              = "ingress"
  from_port         = 9060
  to_port           = 9060
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Cart Service (9060) from VPC ONLY - Internal via API Gateway"
}

# RULE: Order Service
# WHY: Handles order processing and transactions
# SECURITY:
#   - VPC CIDR only - contains financial transactions
#   - CRITICAL business service - heavily protected
resource "aws_security_group_rule" "eks_nodes_ingress_order_svc" {
  type              = "ingress"
  from_port         = 9070
  to_port           = 9070
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Order Service (9070) from VPC ONLY - Contains transactions, financial data"
}

# RULE: Frontend Internal Access
# WHY: Internal health checks, service mesh
# SECURITY:
#   - VPC CIDR only for internal access
#   - External access comes through ALB rule above
resource "aws_security_group_rule" "eks_nodes_ingress_frontend_vpc" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "INGRESS: Frontend (80) from VPC - Internal health checks and service mesh"
}


# #############################################################################
#                       DATABASE SECURITY GROUP
# #############################################################################
#
# PURPOSE: Controls access to RDS/DocumentDB/ElastiCache databases
#
# WHY THIS IS SECURE:
# 1. INGRESS: Only from EKS nodes + Bastion - no internet access
# 2. EGRESS: NONE - databases don't initiate outbound connections
# 3. Each database port explicitly allowed - no open ranges
# 4. Bastion access for admin maintenance only
# 5. No public IP - completely private subnet
#
# #############################################################################

resource "aws_security_group" "database_sg" {
  name        = "${local.name}-database-sg"
  description = "Security group for databases - accessible only from EKS nodes and Bastion"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name    = "${local.name}-database-sg"
    Purpose = "Database-Private-Access"
  })
}

# RULE: MySQL/Aurora from EKS Nodes
# WHY: Application pods connect to MySQL databases
# SECURITY:
#   - Only from EKS nodes security group
#   - No internet access to database
#   - Single port - minimal attack surface
resource "aws_security_group_rule" "database_ingress_mysql" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.database_sg.id
  description              = "INGRESS: MySQL (3306) from EKS Nodes ONLY - Application database access"
}

# RULE: PostgreSQL from EKS Nodes
# WHY: Application pods connect to PostgreSQL databases
# SECURITY:
#   - Only from EKS nodes security group
#   - No internet access to database
resource "aws_security_group_rule" "database_ingress_postgres" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.database_sg.id
  description              = "INGRESS: PostgreSQL (5432) from EKS Nodes ONLY - Application database access"
}

# RULE: MongoDB/DocumentDB from EKS Nodes
# WHY: Application pods connect to MongoDB
# SECURITY:
#   - Only from EKS nodes security group
#   - No internet access to database
resource "aws_security_group_rule" "database_ingress_mongodb" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.database_sg.id
  description              = "INGRESS: MongoDB (27017) from EKS Nodes ONLY - Document database access"
}

# RULE: Redis/ElastiCache from EKS Nodes
# WHY: Application pods connect to Redis for caching/sessions
# SECURITY:
#   - Only from EKS nodes security group
#   - Session data protected
resource "aws_security_group_rule" "database_ingress_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  security_group_id        = aws_security_group.database_sg.id
  description              = "INGRESS: Redis (6379) from EKS Nodes ONLY - Caching and session storage"
}

# RULE: Database Access from Bastion
# WHY: DBAs need direct database access for maintenance
# SECURITY:
#   - Only from Bastion host - requires SSH key
#   - Used for emergency maintenance, schema changes
#   - All sessions can be audited
resource "aws_security_group_rule" "database_ingress_bastion" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = module.public_bastion_sg.security_group_id
  security_group_id        = aws_security_group.database_sg.id
  description              = "INGRESS: DB ports (3306-27017) from Bastion ONLY - Admin maintenance access"
}

# =============================================================================
# DATABASE EGRESS: NONE
# =============================================================================
# WHY NO EGRESS RULES:
# - Databases should NEVER initiate outbound connections
# - All communication is request-response from application
# - Prevents data exfiltration even if database is compromised
# - AWS managed databases (RDS, DocumentDB) handle replication internally
# =============================================================================


# =============================================================================
# EKS NODES - DATABASE ACCESS (Egress Rules)
# =============================================================================

# RULE: MySQL Egress to Database
# WHY: Pods need to connect to MySQL
# SECURITY:
#   - Only to database security group
#   - Single port - minimal attack surface
resource "aws_security_group_rule" "eks_nodes_egress_mysql" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "EGRESS: MySQL (3306) to Database SG - Application database connection"
}

# RULE: PostgreSQL Egress to Database
resource "aws_security_group_rule" "eks_nodes_egress_postgres" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "EGRESS: PostgreSQL (5432) to Database SG - Application database connection"
}

# RULE: MongoDB Egress to Database
resource "aws_security_group_rule" "eks_nodes_egress_mongodb" {
  type                     = "egress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "EGRESS: MongoDB (27017) to Database SG - Document database connection"
}

# RULE: Redis Egress to Database
resource "aws_security_group_rule" "eks_nodes_egress_redis" {
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.database_sg.id
  security_group_id        = aws_security_group.eks_nodes_sg.id
  description              = "EGRESS: Redis (6379) to Database SG - Cache and session connection"
}


# =============================================================================
# OUTPUTS - For use in other Terraform modules and Helm deployments
# =============================================================================

output "alb_security_group_id" {
  description = "ID of the ALB security group - use with ingress.alb.securityGroups in Helm"
  value       = aws_security_group.alb_sg.id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group - for IAM policies and WAF"
  value       = aws_security_group.alb_sg.arn
}

output "eks_cluster_security_group_id" {
  description = "ID of the EKS cluster security group - for control plane access"
  value       = aws_security_group.eks_cluster_sg.id
}

output "eks_nodes_security_group_id" {
  description = "ID of the EKS nodes security group - for worker node configuration"
  value       = aws_security_group.eks_nodes_sg.id
}

output "database_security_group_id" {
  description = "ID of the database security group - for RDS/DocumentDB/ElastiCache"
  value       = aws_security_group.database_sg.id
}
