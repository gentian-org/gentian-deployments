# Gentian Deployments

This repository is the GitOps source of truth for cluster-specific Gentian
configuration and tenant manifests.

## Repository layout

The structure is cluster-first and tenant-centric:

```text
profiles/
  _base.yaml               # shared across every stage (app-catalogue-specific, not chart-generic)
  <stage>.yaml              # tier-wide policy, shared by every cluster of that stage
clusters/
  <cluster>/
    kernel/
      cluster-settings.env   # hand-maintained: network mode, storage class, mail, etc.
      claims/
        cluster.yaml          # kernelDomain — the single source of truth for this cluster
        infra-data.yaml
        suze.yaml
      values.yaml             # cluster-unique Helm overlay (deltas only — see kernelDomain above)
      gentian-corp.yaml         # optional add-on — NOT scaffolded, hand-added (see below)
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

Note what's **not** here: `app-of-apps.yaml`, `gentian-portal.yaml`,
`image-updater.yaml`. Those ArgoCD `Application`/`ImageUpdater` objects are
near-identical across every cluster, so instead of committing a copy per
cluster they live as `.tmpl` files in `gentian-os` itself
(`kernel/bootstrap/gentian-os-application.yaml.tmpl`,
`gentian-portal-application.yaml.tmpl`), rendered with `%CLUSTER%`/`%STAGE%`
and `kubectl apply`'d directly by `install.sh` — never committed here at
all. See
[gentian-os/docs/deployment.md](../gentian-os/docs/deployment.md) §3.1.

**Kernel instance data vs. optional add-ons vs. tenant apps.** All three
can look like they belong under `kernel/`, but only the first two are
committed here:

- **Kernel instance data** — genuinely unique per cluster (Crossplane
  Claims, `values.yaml`). Scaffolded automatically by `gentian-os/install.sh`
  on first bootstrap (from `KERNEL_DOMAIN` + `GENTIAN_DEPLOYMENTS_STAGE` in
  `install.env`), committed straight to `main` — no PR, since nothing is
  running yet at that point. `cluster-settings.env` is the one exception:
  hand-maintained, never generated, since network mode/storage
  class/mail config aren't derivable from those two inputs.
- **Optional cluster add-ons** — `gentian-corp.yaml` is the example here: a
  private, org-specific app that most gentian-os deployments don't run.
  Same directory, same ArgoCD `Application` shape, but nothing scaffolds it
  — add it by hand only on the cluster(s) that actually want it.
- **Tenant apps** (Nextcloud, OpenProject, ...) aren't in `kernel/` at all
  — see "Tenant definitions" below.

See [gentian-os/docs/deployment.md](../gentian-os/docs/deployment.md)
§1/§3 for the full layered-config model, bootstrap sequence, and the
kernel/add-on/tenant distinction in detail.

## How bootstrap resolves paths

`gentian-os/install.sh` and `update.sh` render Argo Applications from:

- `profiles/_base.yaml` then `profiles/<stage>.yaml` (Layer 2 — shared, then tier policy)
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
