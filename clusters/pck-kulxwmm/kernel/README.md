# Cluster Kernel Values — pck-kulxwmm (production)

Infomaniak Public Cloud cluster running **prod** only (`gentian.cloud`).

## Released OS version

| Component | Pin |
|---|---|
| gentian-os chart + operator image | **`v0.1.2`** (tag on `gentian-org/gentian-os`) |
| gentian-deployments | `main` |
| Image Updater policy | `semver:v0.1.*` (patch releases within 0.1.x) |

## Bootstrap

`install.env` on the cloud machine:

```bash
GENTIAN_DEPLOYMENTS_CLUSTER=pck-kulxwmm
GENTIAN_DEPLOYMENTS_STAGE=prod
GENTIAN_DEPLOYMENTS_BRANCH=main
```

Run install from the **v0.1.2** tag (not `develop`):

```bash
cd gentian-os
git fetch --tags
git checkout v0.1.2
./install.sh --validate
./install.sh
```

Optional secrets for full App Store lifecycle in-cluster:

- `GENTIAN_DEPLOYMENTS_GIT_TOKEN` in `install.secrets.env` (PAT with `contents:write` on `gentian-deployments`)
- `appLifecycle.deployments` is enabled in `values-prod.yaml`

## Active files

- `cluster-settings.env` — domain, static IP, storage, mail
- `values-base.yaml` / `values-prod.yaml` — operator Helm values
- `image-updater-prod.yaml` — conservative image updates
- `app-of-apps-prod.yaml` — ArgoCD Application + ApplicationSet (`tenants/*/prod`)

Unused stage directories were removed; this cluster only defines `prod` kernel files.

See [gentian-os/docs/deployment.md](../../../../gentian-os/docs/deployment.md).
