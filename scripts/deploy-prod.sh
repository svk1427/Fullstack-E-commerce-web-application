#!/bin/bash
# =============================================================================
# PRODUCTION DEPLOYMENT SCRIPT
# =============================================================================
# Safe deployment script with environment verification
# Usage: ./scripts/deploy-prod.sh [service-name|all]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/../helm-charts"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# PRODUCTION CONFIGURATION
# =============================================================================
EXPECTED_AWS_ACCOUNT="855561838951"
EXPECTED_CLUSTER="prod-eks-cluster"
NAMESPACE="prod"
REGION="us-east-1"

# =============================================================================
# SAFETY CHECKS
# =============================================================================

echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                    ⚠️  PRODUCTION DEPLOYMENT ⚠️                            ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check 1: AWS Account
echo -e "${BLUE}Checking AWS Account...${NC}"
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
if [ "$CURRENT_ACCOUNT" != "$EXPECTED_AWS_ACCOUNT" ]; then
    echo -e "${RED}ERROR: Wrong AWS Account!${NC}"
    echo "Expected: $EXPECTED_AWS_ACCOUNT"
    echo "Current:  $CURRENT_ACCOUNT"
    exit 1
fi
echo -e "${GREEN}✓ AWS Account: $CURRENT_ACCOUNT${NC}"

# Check 2: Kubernetes Context
echo -e "${BLUE}Checking Kubernetes Context...${NC}"
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != *"$EXPECTED_CLUSTER"* ]]; then
    echo -e "${RED}ERROR: Wrong Kubernetes Cluster!${NC}"
    echo "Expected cluster: $EXPECTED_CLUSTER"
    echo "Current context:  $CURRENT_CONTEXT"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes Context: $CURRENT_CONTEXT${NC}"

# Check 3: Cluster connectivity
echo -e "${BLUE}Checking Cluster Connectivity...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}ERROR: Cannot connect to cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cluster is reachable${NC}"

echo ""
echo -e "${YELLOW}Environment Summary:${NC}"
echo "  AWS Account:  $CURRENT_ACCOUNT"
echo "  EKS Cluster:  $EXPECTED_CLUSTER"
echo "  Region:       $REGION"
echo "  Namespace:    $NAMESPACE"
echo ""

# Confirmation
read -p "Type 'DEPLOY-PROD' to confirm: " confirm
if [ "$confirm" != "DEPLOY-PROD" ]; then
    echo "Deployment cancelled."
    exit 1
fi

# =============================================================================
# DEPLOYMENT
# =============================================================================

echo ""
echo -e "${BLUE}Starting Production Deployment...${NC}"
echo ""

# Create namespace if not exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Service to deploy
SERVICE=$1

deploy_service() {
    local service=$1
    local chart_dir="$HELM_DIR/$service"
    local prod_override="$HELM_DIR/environments/prod/$service.yaml"
    
    echo -e "${BLUE}Deploying $service...${NC}"
    
    if [ -f "$prod_override" ]; then
        helm upgrade --install $service $chart_dir \
            --namespace $NAMESPACE \
            -f $prod_override \
            --wait --timeout 5m
    else
        helm upgrade --install $service $chart_dir \
            --namespace $NAMESPACE \
            --wait --timeout 5m
    fi
    
    echo -e "${GREEN}✓ $service deployed${NC}"
}

if [ "$SERVICE" == "all" ] || [ -z "$SERVICE" ]; then
    # Deploy in order
    echo -e "${YELLOW}Deploying all services...${NC}"
    
    deploy_service "service-registry"
    sleep 30  # Wait for Eureka to be ready
    
    # Deploy microservices
    for svc in auth-service user-service product-service category-service cart-service order-service notification-service; do
        deploy_service $svc
    done
    
    deploy_service "api-gateway"
    deploy_service "web-app"
    deploy_service "ingress-alb"
else
    deploy_service $SERVICE
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✓ PRODUCTION DEPLOYMENT COMPLETE                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show deployment status
echo -e "${BLUE}Deployment Status:${NC}"
kubectl get pods -n $NAMESPACE
