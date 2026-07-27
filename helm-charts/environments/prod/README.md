# =============================================================================
# PRODUCTION ENVIRONMENT - README
# =============================================================================
# Base values.yaml files ARE the production values.
# Use these override files ONLY for environment-specific secrets/endpoints.
# =============================================================================

# For production deployment, simply use:
#   helm upgrade --install <service> ./<service-chart>
#
# The base values.yaml already contains:
#   - Production replica counts (3 for most services)
#   - HPA enabled with proper scaling
#   - PDB enabled for high availability
#   - Pod anti-affinity for fault tolerance
#   - Production-grade resource limits
#   - WARN log levels
