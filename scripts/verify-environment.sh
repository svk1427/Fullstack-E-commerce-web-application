#!/bin/bash
# =============================================================================
# DEPLOYMENT SAFETY SCRIPT
# =============================================================================
# Run this BEFORE any deployment to verify you're in the correct environment
# Usage: ./scripts/verify-environment.sh prod
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Environment configurations
declare -A PROD_CONFIG
PROD_CONFIG[account_id]="855561838951"
PROD_CONFIG[cluster]="prod-eks-cluster"
PROD_CONFIG[namespace]="prod"
PROD_CONFIG[region]="us-east-1"

declare -A QA_CONFIG
QA_CONFIG[account_id]="234567890123"  # Update with your QA account
QA_CONFIG[cluster]="qa-eks-cluster"
QA_CONFIG[namespace]="qa"
QA_CONFIG[region]="us-east-1"

declare -A DEV_CONFIG
DEV_CONFIG[account_id]="123456789012"  # Update with your dev account
DEV_CONFIG[cluster]="dev-eks-cluster"
DEV_CONFIG[namespace]="dev"
DEV_CONFIG[region]="us-east-1"

# =============================================================================
# FUNCTIONS
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE} ENVIRONMENT VERIFICATION: $1${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

verify_aws_account() {
    local expected_account=$1
    local current_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    
    if [ "$current_account" == "$expected_account" ]; then
        print_success "AWS Account: $current_account"
        return 0
    else
        print_error "AWS Account mismatch!"
        echo "    Expected: $expected_account"
        echo "    Current:  $current_account"
        return 1
    fi
}

verify_eks_cluster() {
    local expected_cluster=$1
    local expected_region=$2
    local current_context=$(kubectl config current-context 2>/dev/null)
    
    if [[ "$current_context" == *"$expected_cluster"* ]]; then
        print_success "EKS Cluster: $expected_cluster"
        return 0
    else
        print_error "EKS Cluster mismatch!"
        echo "    Expected cluster: $expected_cluster"
        echo "    Current context:  $current_context"
        return 1
    fi
}

verify_namespace() {
    local expected_ns=$1
    local current_ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
    
    # If no namespace set, default is "default"
    if [ -z "$current_ns" ]; then
        current_ns="default"
    fi
    
    echo "    Current namespace: $current_ns"
    echo "    Target namespace:  $expected_ns"
    print_warning "Ensure you deploy to namespace: $expected_ns"
    return 0
}

# =============================================================================
# MAIN
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: $0 <environment>"
    echo "Environments: dev, qa, prod"
    exit 1
fi

ENV=$1

case $ENV in
    prod|production)
        print_header "PRODUCTION"
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                    ⚠️  PRODUCTION ENVIRONMENT ⚠️                          ║${NC}"
        echo -e "${RED}║                    PROCEED WITH EXTREME CAUTION                           ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        ERRORS=0
        verify_aws_account "${PROD_CONFIG[account_id]}" || ERRORS=$((ERRORS+1))
        verify_eks_cluster "${PROD_CONFIG[cluster]}" "${PROD_CONFIG[region]}" || ERRORS=$((ERRORS+1))
        verify_namespace "${PROD_CONFIG[namespace]}"
        
        if [ $ERRORS -gt 0 ]; then
            echo ""
            print_error "VERIFICATION FAILED! Do not proceed with deployment."
            exit 1
        fi
        
        echo ""
        print_success "All verifications passed for PRODUCTION"
        echo ""
        read -p "Type 'DEPLOY-PROD' to confirm deployment: " confirm
        if [ "$confirm" != "DEPLOY-PROD" ]; then
            echo "Deployment cancelled."
            exit 1
        fi
        ;;
        
    qa)
        print_header "QA"
        verify_aws_account "${QA_CONFIG[account_id]}" || exit 1
        verify_eks_cluster "${QA_CONFIG[cluster]}" "${QA_CONFIG[region]}" || exit 1
        verify_namespace "${QA_CONFIG[namespace]}"
        print_success "All verifications passed for QA"
        ;;
        
    dev|development)
        print_header "DEVELOPMENT"
        verify_aws_account "${DEV_CONFIG[account_id]}" || exit 1
        verify_eks_cluster "${DEV_CONFIG[cluster]}" "${DEV_CONFIG[region]}" || exit 1
        verify_namespace "${DEV_CONFIG[namespace]}"
        print_success "All verifications passed for DEVELOPMENT"
        ;;
        
    *)
        print_error "Unknown environment: $ENV"
        echo "Valid environments: dev, qa, prod"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✓ Environment verification complete. Safe to deploy.${NC}"
echo ""
