#!/bin/bash
# =============================================================================
# MONITORING STACK DEPLOYMENT SCRIPT
# =============================================================================
# Deploys Fluent Bit, Prometheus, Grafana, and Loki to Kubernetes
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${ENVIRONMENT:-dev}"
NAMESPACE="${NAMESPACE:-monitoring}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-}"
HELM_RELEASE_NAME="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHART_DIR="${SCRIPT_DIR}/../helm-charts/monitoring"
VALUES_DIR="${SCRIPT_DIR}/../helm-charts/environments"

# Functions
print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl found"
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install helm first."
        exit 1
    fi
    print_success "helm found"
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
    
    # Check helm chart exists
    if [ ! -d "$HELM_CHART_DIR" ]; then
        print_error "Helm chart not found at: $HELM_CHART_DIR"
        exit 1
    fi
    print_success "Helm chart found"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment    Environment (dev|qa|preprod|prod). Default: dev"
    echo "  -n, --namespace      Kubernetes namespace. Default: monitoring"
    echo "  -p, --password       Grafana admin password (recommended for production)"
    echo "  -u, --uninstall      Uninstall the monitoring stack"
    echo "  -s, --status         Show monitoring stack status"
    echo "  -f, --forward        Port forward Grafana and Prometheus"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev                    # Deploy to dev environment"
    echo "  $0 -e prod -p MySecurePass   # Deploy to prod with custom password"
    echo "  $0 -s                        # Show status"
    echo "  $0 -f                        # Port forward services"
    echo "  $0 -u                        # Uninstall monitoring stack"
}

# Deploy monitoring stack
deploy_monitoring() {
    print_header "Deploying Monitoring Stack"
    
    # Set values file based on environment
    VALUES_FILE="${VALUES_DIR}/${ENVIRONMENT}/monitoring.yaml"
    
    if [ ! -f "$VALUES_FILE" ]; then
        print_warning "Environment-specific values file not found: $VALUES_FILE"
        print_info "Using default values from chart"
        VALUES_FILE=""
    else
        print_info "Using values file: $VALUES_FILE"
    fi
    
    # Build helm command
    HELM_CMD="helm upgrade --install ${HELM_RELEASE_NAME} ${HELM_CHART_DIR}"
    HELM_CMD+=" --namespace ${NAMESPACE}"
    HELM_CMD+=" --create-namespace"
    
    if [ -n "$VALUES_FILE" ]; then
        HELM_CMD+=" -f ${VALUES_FILE}"
    fi
    
    if [ -n "$GRAFANA_PASSWORD" ]; then
        HELM_CMD+=" --set grafana.admin.password=${GRAFANA_PASSWORD}"
    fi
    
    # Execute helm install/upgrade
    print_info "Running: helm upgrade --install ${HELM_RELEASE_NAME}..."
    eval "$HELM_CMD"
    
    print_success "Monitoring stack deployed successfully!"
    
    # Wait for pods to be ready
    print_header "Waiting for Pods to be Ready"
    
    echo "Waiting for Fluent Bit DaemonSet..."
    kubectl rollout status daemonset/fluent-bit -n ${NAMESPACE} --timeout=120s 2>/dev/null || true
    
    echo "Waiting for Node Exporter DaemonSet..."
    kubectl rollout status daemonset/node-exporter -n ${NAMESPACE} --timeout=120s 2>/dev/null || true
    
    echo "Waiting for Prometheus..."
    kubectl rollout status statefulset/prometheus -n ${NAMESPACE} --timeout=180s 2>/dev/null || true
    
    echo "Waiting for Loki..."
    kubectl rollout status statefulset/loki -n ${NAMESPACE} --timeout=180s 2>/dev/null || true
    
    echo "Waiting for Grafana..."
    kubectl rollout status deployment/grafana -n ${NAMESPACE} --timeout=120s 2>/dev/null || true
    
    echo "Waiting for Kube State Metrics..."
    kubectl rollout status deployment/kube-state-metrics -n ${NAMESPACE} --timeout=120s 2>/dev/null || true
    
    print_success "All components are ready!"
    
    # Show access information
    show_access_info
}

# Show access information
show_access_info() {
    print_header "Access Information"
    
    echo -e "${GREEN}Grafana:${NC}"
    echo "  URL: http://localhost:3000 (after port-forward)"
    echo "  Username: admin"
    if [ -n "$GRAFANA_PASSWORD" ]; then
        echo "  Password: (the one you specified)"
    else
        echo "  Password: admin (default, change immediately!)"
    fi
    echo ""
    echo -e "${GREEN}Prometheus:${NC}"
    echo "  URL: http://localhost:9090 (after port-forward)"
    echo ""
    echo -e "${GREEN}Quick Commands:${NC}"
    echo "  Port forward: $0 -f"
    echo "  Check status: $0 -s"
    echo "  Uninstall: $0 -u"
    echo ""
    echo -e "${YELLOW}To port-forward manually:${NC}"
    echo "  kubectl port-forward svc/grafana 3000:3000 -n ${NAMESPACE}"
    echo "  kubectl port-forward svc/prometheus 9090:9090 -n ${NAMESPACE}"
}

# Uninstall monitoring stack
uninstall_monitoring() {
    print_header "Uninstalling Monitoring Stack"
    
    print_warning "This will remove all monitoring components from namespace: ${NAMESPACE}"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm uninstall ${HELM_RELEASE_NAME} -n ${NAMESPACE} 2>/dev/null || true
        print_success "Helm release uninstalled"
        
        read -p "Delete namespace and PVCs? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace ${NAMESPACE} 2>/dev/null || true
            print_success "Namespace deleted"
        fi
    else
        print_info "Uninstall cancelled"
    fi
}

# Show status
show_status() {
    print_header "Monitoring Stack Status"
    
    echo -e "${BLUE}Namespace: ${NAMESPACE}${NC}\n"
    
    echo -e "${GREEN}=== Pods ===${NC}"
    kubectl get pods -n ${NAMESPACE} -o wide 2>/dev/null || print_warning "No pods found"
    
    echo -e "\n${GREEN}=== DaemonSets ===${NC}"
    kubectl get daemonsets -n ${NAMESPACE} 2>/dev/null || print_warning "No daemonsets found"
    
    echo -e "\n${GREEN}=== Deployments ===${NC}"
    kubectl get deployments -n ${NAMESPACE} 2>/dev/null || print_warning "No deployments found"
    
    echo -e "\n${GREEN}=== StatefulSets ===${NC}"
    kubectl get statefulsets -n ${NAMESPACE} 2>/dev/null || print_warning "No statefulsets found"
    
    echo -e "\n${GREEN}=== Services ===${NC}"
    kubectl get services -n ${NAMESPACE} 2>/dev/null || print_warning "No services found"
    
    echo -e "\n${GREEN}=== PVCs ===${NC}"
    kubectl get pvc -n ${NAMESPACE} 2>/dev/null || print_warning "No PVCs found"
}

# Port forward services
port_forward() {
    print_header "Port Forwarding Services"
    
    print_info "Starting port-forward for Grafana (3000) and Prometheus (9090)..."
    print_warning "Press Ctrl+C to stop"
    echo ""
    
    # Start port-forwards in background
    kubectl port-forward svc/grafana 3000:3000 -n ${NAMESPACE} &
    PID1=$!
    kubectl port-forward svc/prometheus 9090:9090 -n ${NAMESPACE} &
    PID2=$!
    
    print_success "Port-forward started!"
    echo ""
    echo -e "${GREEN}Access URLs:${NC}"
    echo "  Grafana:    http://localhost:3000"
    echo "  Prometheus: http://localhost:9090"
    echo ""
    
    # Wait for interrupt
    trap "kill $PID1 $PID2 2>/dev/null" EXIT
    wait
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -p|--password)
            GRAFANA_PASSWORD="$2"
            shift 2
            ;;
        -u|--uninstall)
            ACTION="uninstall"
            shift
            ;;
        -s|--status)
            ACTION="status"
            shift
            ;;
        -f|--forward)
            ACTION="forward"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
check_prerequisites

case ${ACTION:-deploy} in
    uninstall)
        uninstall_monitoring
        ;;
    status)
        show_status
        ;;
    forward)
        port_forward
        ;;
    deploy)
        deploy_monitoring
        ;;
esac
