# Helm Release Outputs
output "lbc_helm_metadata" {
  description = "Metadata Block outlining status of the deployed release."
  value       = helm_release.loadbalancer_controller.metadata
}

# Output: Command to get ALB DNS
output "get_alb_dns_command" {
  description = "Run this command after deploying ingress to get ALB DNS"
  value       = "kubectl get ingress purely-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}