# Gentian Deployments - Tenant Admin Guide

This document is for tenant admins who manage apps for an existing tenant.

Cluster bootstrap is done separately by the cluster admin using the shared OS installer in the gentian-os repository.

## What You Can Do

As tenant admin, you can:

- list available app profiles
- install an app for your tenant
- uninstall an app from your tenant
- check tenant and app reconciliation status

As tenant admin, you do not install the OS and you do not manage kernel components.

## Login and User Provisioning

The platform UIs are served under the cluster kernel domain:

- Portal: https://portal.<KERNEL_DOMAIN>
- Identity admin: https://id.<KERNEL_DOMAIN>
- ArgoCD (read-only for most tenant admins): URL shared by cluster admin

Typical user provisioning flow:

1. Sign in at the shared portal: https://portal.<KERNEL_DOMAIN>/login/
2. Tenant admins manage users via UMC at https://portal.<KERNEL_DOMAIN>/univention/management/
3. Or use Identity admin (Keycloak) for your tenant realm (for example demo).
4. Assign roles/groups required by installed apps.

If you do not have identity admin access, ask cluster admin to provision users/groups for your tenant.

## Required Local Setup

The Gentian OS command interface (`kubectl gentian ...`) reads deployment repository settings from `~/.gentian/config`:

- GENTIAN_DEPLOYMENTS_PATH (local checkout path)
- GENTIAN_DEPLOYMENTS_REPO (remote URL)

Example:

```bash
cat ~/.gentian/config
```

## App Management Commands

List available app profiles:

```bash
kubectl gentian apps list
```

Install app for a tenant:

```bash
kubectl gentian apps install openproject --tenant demo
```

Uninstall app for a tenant:

```bash
kubectl gentian apps uninstall openproject --tenant demo
```

What happens behind the scenes:

1. The Gentian OS command interface updates `spec.apps` in your tenant manifest
2. It commits and pushes the change (Git source of truth for ArgoCD)
3. It applies the tenant manifest to Kubernetes (immediate reconcile)
4. The gentian-os operator creates/updates `App` claims; Crossplane deploys helm Releases

## Useful Operational Checks

Check tenant objects:

```bash
kubectl get tenants
kubectl get tenant demo -o yaml
```

Check tenant app installs:

```bash
kubectl get apps -n tenant-demo
kubectl get releases.helm.crossplane.io -n tenant-demo
```

Check ArgoCD (kernel + catalogue sync, not per-tenant app charts):

```bash
kubectl get applications -n argocd
```

Check operator logs:

```bash
kubectl logs -n gentian-system deploy/gentian-os -f
```

## Tenant Manifests

Tenant manifests live under each environment folder, for example:

- dev/tenants/instances/demo/tenant.yaml
- dev/tenants/kustomization.yaml

Only edit manifests for tenants you are responsible for.

## Tenant app URLs and TLS

Installed apps are served at `{subdomain}.{effectiveDomain}`. The effective domain
depends on cluster **`TENANCY_MODE`** (operator Helm `tenancyMode` / `install.env`):

| Mode | Default effective domain | Example Jitsi on tenant `demo` |
|---|---|---|
| **`multi`** (shared cluster) | `demo.<KERNEL_DOMAIN>` | `https://meet.demo.desk.gentian.org` |
| **`single`** (dedicated cluster) | `<KERNEL_DOMAIN>` (flat) | `https://meet.desk.gentian.org` (tenant must be named `default`) |

Override with `spec.domain` in the tenant manifest for customer vanity zones (e.g.
`acme.com`). Central IdP remains `https://id.<KERNEL_DOMAIN>/realms/<tenant>` in
both modes.

The Gentian OS operator issues a per-tenant wildcard certificate for that zone.
Cluster admins must configure DNS and `TENANT_DNS01_CLUSTER_ISSUER` on the
operator; see [multi-tenancy TLS](../gentian-os/docs/design/multi-tenancy.md) §3.

**Dev:** `dev/kernel/values-dev.yaml` points the operator at Let's Encrypt staging;
set `ACME_ENV=staging` in `install.env` and run `./update.sh --acme-issuers`.
See [dev/kernel/README.md](dev/kernel/README.md).

## Tenant instance lifecycle (cluster admin)

Adding or removing a tenant **instance** (folder under `dev/tenants/instances/`)
is a cluster-admin task via `kubectl gentian tenants deploy|undeploy` — see
[gentian-os/docs/commands.md](../gentian-os/docs/commands.md).

## Environments

Today only **`dev/tenants`** carries tenant instances. **`prod/`** and
**`staging/`** currently hold kernel image-updater config only; tenant
instances there are optional/future.

## Related Docs

Cluster-admin OS commands:

- [gentian-os/docs/commands.md](../gentian-os/docs/commands.md)
- [gentian-os/docs/design/multi-tenancy.md](../gentian-os/docs/design/multi-tenancy.md) (domains and TLS)
- [gentian-os/docs/roadmap.md](../gentian-os/docs/roadmap.md) (planned features)
