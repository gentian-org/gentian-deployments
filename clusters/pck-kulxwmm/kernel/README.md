# Cluster Kernel Values

This directory contains cluster-scoped kernel/operator configuration for
`pck-kulxwmm` (Infomaniak Public Cloud — **production-only** cluster).

## Production bootstrap

| Setting | Value |
|---|---|
| Cluster | `pck-kulxwmm` |
| Stage | `prod` |
| Domain | `gentian.cloud` |
| Network | `static-ip` (`NODE_IP` in `cluster-settings.env`) |
| ACME | production (`ACME_ENV` unset or `production` in `install.env`) |
| Operator image | semver `v*` tags via `image-updater-prod.yaml` |

`install.env` on the cloud machine:

```bash
GENTIAN_DEPLOYMENTS_CLUSTER=pck-kulxwmm
GENTIAN_DEPLOYMENTS_STAGE=prod
GENTIAN_DEPLOYMENTS_BRANCH=main
```

Before first install:

1. Set `CF_API_TOKEN` in `install.secrets.env` with DNS edit on the `gentian.cloud` zone.
2. Point DNS `*.gentian.cloud` (and tenant zones) at the cluster LoadBalancer / `NODE_IP`.
3. Run `./install.sh` from a `gentian-os` checkout on `main` (or a release tag after v1.0.0).

Optional day-2 Argo bootstrap (if not created by `install.sh`):

```bash
kubectl apply -f clusters/pck-kulxwmm/kernel/app-of-apps-prod.yaml
```

## Active files (prod)

- `cluster-settings.env` — installer-sourced cluster runtime (domain, IP, storage, mail)
- `values-base.yaml` — shared operator values
- `values-prod.yaml` — production operator overlay (domain, issuer, image policy)
- `image-updater-prod.yaml` — conservative semver image updates
- `app-of-apps-prod.yaml` — ArgoCD Application + ApplicationSet for `prod`

Unused stage slots are marked under `stages/` (see `stages/README.md`).

Argo bootstrap in `gentian-os` uses these paths:

- `clusters/pck-kulxwmm/kernel/values-base.yaml`
- `clusters/pck-kulxwmm/kernel/values-<stage>.yaml`
- `clusters/pck-kulxwmm/kernel/image-updater-<stage>.yaml`
- `clusters/pck-kulxwmm/tenants/*/<stage>` (ApplicationSet directory generator)

See [gentian-os/docs/deployment.md](../../../../gentian-os/docs/deployment.md) for
how cluster and stage map to environments and promotion flows.
