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
    examples/
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

## Tenant manifests

Fresh installs leave `clusters/<cluster>/tenants/` **empty**. Nothing under
`tenants/*/<stage>` is deployed until a cluster admin adds manifests.

Reference examples (not auto-deployed) live under:

- `clusters/<cluster>/examples/<tenant>/<stage>/`

Live tenant definitions belong under:

- `clusters/<cluster>/tenants/<tenant>/<stage>/tenant.yaml`

Argo discovers and deploys tenant stage directories through the
`gentian-tenants` ApplicationSet once they exist under `tenants/`.

## Operator and app commands

```bash
kubectl gentian tenants list
kubectl gentian tenants deploy demo    # scaffolds from examples/demo/<stage>/ on first run
kubectl gentian tenants undeploy demo
kubectl gentian apps list
kubectl gentian apps install openproject --tenant demo
```

## Security note

This repository can be public for demo setups, but never commit raw secrets.
Use OpenBao + External Secrets and keep credentials outside Git.

## Related docs

- [gentian-os/docs/commands.md](../gentian-os/docs/commands.md)
- [gentian-os/docs/design/multi-tenancy.md](../gentian-os/docs/design/multi-tenancy.md)
- [gentian-os/docs/design/security.md](../gentian-os/docs/design/security.md)
