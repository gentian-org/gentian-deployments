# Tenant stage placeholders

Activated tenants are synced from `../<tenant>/<stage>/` (not from this
`stages/` tree). This cluster runs `prod` only; `dev/` and `staging/` here
mark unused stage slots.

When a cluster admin deploys a tenant (`kubectl gentian tenants deploy
<name>`), manifests appear under:

```text
tenants/<tenant>/prod/
```

Until then, `tenants/` stays empty aside from shared `components/`.
