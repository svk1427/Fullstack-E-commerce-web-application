#!/bin/bash
# =============================================================================
# CoreDNS Validation Script
# =============================================================================

NAMESPACE="${1:-ecommerce}"
echo "🔍 Validating CoreDNS for namespace: $NAMESPACE"
echo "=============================================="

# 1. Check CoreDNS pods
echo ""
echo "📦 1. CoreDNS Pods:"
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check CoreDNS service
echo ""
echo "🌐 2. CoreDNS Service:"
kubectl get svc -n kube-system kube-dns

# 3. List services in target namespace
echo ""
echo "📋 3. Services in $NAMESPACE namespace:"
kubectl get svc -n $NAMESPACE

# 4. Test DNS resolution
echo ""
echo "🧪 4. Testing DNS Resolution..."

SERVICES=("auth-svc" "cart-svc" "gateway-svc" "registry-svc" "product-svc" "order-svc" "category-svc" "user-svc" "web-app-svc")

for SVC in "${SERVICES[@]}"; do
    echo ""
    echo "   Testing: $SVC"
    kubectl run dns-test-$RANDOM --image=busybox:1.28 --rm -it --restart=Never -n $NAMESPACE --quiet -- nslookup $SVC 2>/dev/null | head -5
done

# 5. Check CoreDNS logs for errors
echo ""
echo "📜 5. Recent CoreDNS Logs (last 20 lines):"
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20

# 6. Check CoreDNS ConfigMap
echo ""
echo "⚙️ 6. CoreDNS Configuration:"
kubectl get configmap coredns -n kube-system -o yaml

echo ""
echo "✅ CoreDNS validation complete!"
