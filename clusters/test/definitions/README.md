# Tenant definitions

Tenant definitions live under `clusters/<cluster>/definitions/<tenant>/<stage>/`.
They describe what a tenant is (apps, isolation, admin email) before it is deployed.

Fresh installs keep `clusters/<cluster>/tenants/` empty so ArgoCD does not sync
any tenants until a cluster admin activates a definition.

| Path | Meaning |
|------|---------|
| `definitions/<tenant>/<stage>/` | Defined — available in `kubectl gentian tenants list` (`ACTIVE=no`) |
| `tenants/<tenant>/<stage>/` | Deployed to GitOps — ArgoCD sync path (`ACTIVE=yes`) |

Activate a definition:

```bash
kubectl gentian tenants deploy demo
```

This copies the definition into `tenants/` and applies it to the cluster.

The `gentian-tenants` ApplicationSet only watches `clusters/<cluster>/tenants/*/<stage>`.
