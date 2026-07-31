# Ingress Class: ALB
# The ALB IngressClass is automatically created by the AWS Load Balancer Controller Helm chart
# No need to create it manually - just reference the name directly

# Output: ALB Ingress Class Name
output "ingress_class_name" {
  description = "Ingress Class Name for ALB"
  value       = "alb"
  depends_on  = [helm_release.loadbalancer_controller]
}

## Additional Note
# 1. You can mark a particular IngressClass as the default for your cluster. 
# 2. Setting the ingressclass.kubernetes.io/is-default-class annotation to true on an IngressClass resource will ensure that new Ingresses without an ingressClassName field specified will be assigned this default IngressClass.  
# 3. Reference: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/guide/ingress/ingress_class/