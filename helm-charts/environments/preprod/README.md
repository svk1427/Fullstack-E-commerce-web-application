# =============================================================================
# PREPROD ENVIRONMENT - README
# =============================================================================
# Pre-production environment for final validation before production release
# 
# Namespace: preprod
# Purpose: Final testing with production-like settings
# =============================================================================

## Preprod Environment Configuration

Preprod uses **base production values** with minimal overrides.
This ensures preprod mirrors production as closely as possible.

### Key Differences from Production (ecommerce namespace):

| Setting | Preprod | Production |
|---------|---------|------------|
| Namespace | `preprod` | `ecommerce` |
| Replicas | Same as prod | Same |
| Resources | Same as prod | Same |
| Database | Separate preprod DB | Production DB |
| Domain | preprod.yourdomain.com | www.yourdomain.com |

### Deployment Flow:

```
Push to main → ecommerce namespace (production)
               ↓
Manual dispatch → preprod namespace (pre-production validation)
```

### Usage:

```bash
# Deploy to preprod via GitHub Actions
# Actions → Workflow → Run workflow → Select "preprod"

# Or manually:
helm upgrade --install auth-service ./auth-service \
  --namespace preprod \
  -f environments/preprod/auth-service.yaml
```

### Note:
Most services use base values.yaml (production settings) for preprod.
Only create override files here if preprod needs different configs (e.g., different DB connection).
