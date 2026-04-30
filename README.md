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

1. Sign in to Identity admin (Keycloak/Nubus) with credentials provided by cluster admin.
2. Open your tenant realm (for example gtn-demo).
3. Create users and groups for your tenant.
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
kubectl gentian apps install openproject --tenant gtn-demo
```

Uninstall app for a tenant:

```bash
kubectl gentian apps uninstall openproject --tenant gtn-demo
```

What happens behind the scenes:

1. The Gentian OS command interface updates your tenant manifest in this repository
2. It commits and pushes the change
3. It applies the tenant manifest to Kubernetes
4. Operator reconciles app resources

## Useful Operational Checks

Check tenant objects:

```bash
kubectl get tenants
kubectl get tenant gtn-demo -o yaml
```

Check ArgoCD app sync status:

```bash
kubectl get applications -n argocd
```

Check operator logs:

```bash
kubectl logs -n gentian-system deploy/gentian-os -f
```

## Tenant Manifests

Tenant manifests are stored under environment folders, for example:

- dev/tenants/dev-tenant.yaml

Only edit manifests for tenants you are responsible for.

## Related Docs

Cluster-admin OS commands are documented in:

- ../gentian-os/docs/commands.md
