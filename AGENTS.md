# AGENTS.md — gentian-deployments

## Project overview

`gentian-deployments` is the GitOps source of truth for cluster-specific Gentian
configuration and tenant manifests — cluster-first, tenant-centric layout under `clusters/`,
`profiles/`, `definitions/`, `tenants/`. See [README.md](README.md) for the full layout and
[gentian-os/docs/deployment.md](https://github.com/gentian-org/gentian-os/blob/main/docs/deployment.md)
for the layered-config model this repo implements.

## Build & deployment — GitOps only, no direct cluster changes

* There is no build step here — this repo *is* the deployment config. Changes are picked up by
  ArgoCD (kernel/add-ons) and the `gentian-tenants` ApplicationSet (tenant apps).
* **Never patch the live cluster directly** (`kubectl edit`, `kubectl patch`, port-forward-and-poke,
  etc.) — every change must land in this repo (or `gentian-os` for kernel defaults) and be
  reconciled by ArgoCD. This is the one repo where that rule matters most, since it's the direct
  input to every cluster's state.
* Accelerating reconciliation — e.g. deleting a stuck resource so ArgoCD/the operator recreates
  it cleanly — is fine. Manually recreating or hand-editing it with different config instead of
  fixing the committed manifest is not.

## Security & licensing

* **Never commit raw secrets.** This repo can be public for demo setups (see README's Security
  note) — secrets are provisioned via OpenBao + External Secrets, never committed in plaintext.
* **Respect third-party license terms** for any vendored manifests or charts referenced from
  here.
