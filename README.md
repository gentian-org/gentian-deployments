# Gentian Deployments

This repository is the GitOps source of truth for cluster-specific Gentian
configuration and tenant manifests.

## Repository layout

The structure is cluster-first and tenant-centric:

```text
clusters/
  <cluster>/
    kernel/
      values-base.yaml
      values-<stage>.yaml
      image-updater-<stage>.yaml
      app-of-apps-<stage>.yaml
    definitions/
      <tenant>/
        dev/
    tenants/
      components/
      <tenant>/
        dev/
        staging/
        prod/
```

Current cluster in this repository:

- `clusters/pck-kulxwmm`
- `clusters/test`

## How bootstrap resolves paths

`gentian-os/install.sh` and `update.sh` render Argo Applications from:

- `clusters/<cluster>/kernel/values-base.yaml`
- `clusters/<cluster>/kernel/values-<stage>.yaml`
- `clusters/<cluster>/kernel/image-updater-<stage>.yaml`
- `clusters/<cluster>/tenants/*/<stage>` (ApplicationSet git directory generator)

where `<cluster>` and `<stage>` come from:

- `GENTIAN_DEPLOYMENTS_CLUSTER`
- `GENTIAN_DEPLOYMENTS_STAGE`

## Tenant definitions

Each cluster keeps tenant **definitions** under:

- `clusters/<cluster>/definitions/<tenant>/<stage>/tenant.yaml`

Fresh installs leave `clusters/<cluster>/tenants/` **empty** until a definition
is deployed. `kubectl gentian tenants list` shows all definitions;
`ACTIVE=no` means defined only, `ACTIVE=yes` means activated under `tenants/`.

Deploy path (GitOps sync target):

- `clusters/<cluster>/tenants/<tenant>/<stage>/tenant.yaml`

Argo discovers activated tenants through the `gentian-tenants` ApplicationSet.

## Operator and app commands

```bash
kubectl gentian tenants list
kubectl gentian tenants deploy demo    # activate definition under tenants/
kubectl gentian tenants undeploy demo
kubectl gentian apps list
kubectl gentian apps install openproject --tenant demo
```

## Security note

This repository can be public for demo setups, but never commit raw secrets.
Use OpenBao + External Secrets and keep credentials outside Git.

## Related docs

- [gentian-os/docs/commands.md](../gentian-os/docs/commands.md)
- [gentian-os/docs/design/gateway.md](../gentian-os/docs/design/gateway.md)
- [gentian-os/docs/design/multi-tenancy.md](../gentian-os/docs/design/multi-tenancy.md)
- [gentian-os/docs/design/security.md](../gentian-os/docs/design/security.md)
