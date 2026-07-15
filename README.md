# Gentian Deployments

This repository is the GitOps source of truth for cluster-specific Gentian
configuration and tenant manifests.

## Repository layout

The structure is cluster-first and tenant-centric:

```text
profiles/
  <stage>.yaml            # tier-wide policy, shared by every cluster of that stage
clusters/
  <cluster>/
    kernel/
      cluster-settings.env   # hand-maintained: network mode, storage class, mail, etc.
      claims/
        cluster.yaml          # kernelDomain — the single source of truth for this cluster
        infra-data.yaml
        suze.yaml
      values.yaml             # cluster-unique Helm overlay (deltas only — see kernelDomain above)
      app-of-apps.yaml
      image-updater.yaml
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

- `clusters/test`

Everything under a cluster's `kernel/` directory except `cluster-settings.env`
is scaffolded automatically by `gentian-os/install.sh` on first bootstrap
(from `KERNEL_DOMAIN` + `GENTIAN_DEPLOYMENTS_STAGE` in `install.env`) and
committed straight to `main` — no PR, since nothing is running yet at that
point. See
[gentian-os/docs/deployment.md](../gentian-os/docs/deployment.md) §1/§3 for
the full layered-config model and bootstrap sequence.

## How bootstrap resolves paths

`gentian-os/install.sh` and `update.sh` render Argo Applications from:

- `profiles/<stage>.yaml` (Layer 2 — tier policy)
- `clusters/<cluster>/kernel/values.yaml` (Layer 3 — cluster overlay)
- `clusters/<cluster>/kernel/claims/*.yaml` (Crossplane Claims)
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

- [gentian-os/docs/deployment.md](../gentian-os/docs/deployment.md)
- [gentian-os/docs/commands.md](../gentian-os/docs/commands.md)
- [gentian-os/docs/design/gateway.md](../gentian-os/docs/design/gateway.md)
- [gentian-os/docs/design/multi-tenancy.md](../gentian-os/docs/design/multi-tenancy.md)
- [gentian-os/docs/design/security.md](../gentian-os/docs/design/security.md)
