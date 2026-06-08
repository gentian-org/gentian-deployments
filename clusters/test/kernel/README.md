# Cluster Kernel Values

This directory contains cluster-scoped kernel/operator configuration for
`test`.

Files:

- `values-base.yaml` — shared operator values across all stages
- `values-dev.yaml` — operator values used for dev stage
- `values-staging.yaml` — operator values used for staging stage
- `values-prod.yaml` — operator values used for prod stage
- `image-updater-dev.yaml` / `image-updater-staging.yaml` / `image-updater-prod.yaml`
  — stage-specific ImageUpdater CRs
- `app-of-apps-dev.yaml` — optional direct app-of-apps bootstrap for dev

Argo bootstrap in `gentian-os` uses these paths:

- `clusters/test/kernel/values-base.yaml`
- `clusters/test/kernel/values-<stage>.yaml`
- `clusters/test/kernel/image-updater-<stage>.yaml`
- `clusters/test/tenants/*/<stage>` (ApplicationSet directory generator)
