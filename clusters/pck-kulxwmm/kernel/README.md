# Cluster Kernel Values

This directory contains cluster-scoped kernel/operator configuration for
`pck-kulxwmm`.

Files:

- `values-base.yaml` — shared operator values across all stages
- `values-dev.yaml` — operator values used for dev stage
- `values-staging.yaml` — operator values used for staging stage
- `values-prod.yaml` — operator values used for prod stage
- `image-updater-dev.yaml` / `image-updater-staging.yaml` / `image-updater-prod.yaml`
  — stage-specific ImageUpdater CRs
- `app-of-apps-dev.yaml` — optional direct app-of-apps bootstrap for dev

Argo bootstrap in `gentian-os` uses these paths:

- `clusters/pck-kulxwmm/kernel/values-base.yaml`
- `clusters/pck-kulxwmm/kernel/values-<stage>.yaml`
- `clusters/pck-kulxwmm/kernel/image-updater-<stage>.yaml`
- `clusters/pck-kulxwmm/tenants/*/<stage>` (ApplicationSet directory generator)

See [gentian-os/docs/deployment.md](../../../../gentian-os/docs/deployment.md) for
how cluster and stage map to environments and promotion flows.
