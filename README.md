# gentian-deployments

Deployment configuration repository for the Gentian stack.

This is **Repo 3** in the three-repo architecture (see [architecture §7](https://github.com/gentian-org/gentian-os/blob/develop/docs/architecture.md)):

| Repo | Purpose |
|------|---------|
| [gentian-os](https://github.com/gentian-org/gentian-os) | Operator, CRDs, Helm chart, kernel services config |
| [gentian-apps](https://github.com/gentian-org/gentian-apps) | Community AppProfiles (future) |
| **gentian-deployments** | This repo — environment-specific config, Tenant CRs |

---

## Repository structure

```
gentian-deployments/
├── dev/
│   ├── bootstrap/
│   │   └── install.sh           # Full bootstrap: installs all dependencies on a fresh cluster
│   ├── kernel/
│   │   ├── values-dev.yaml      # gentian-os Helm chart overrides for dev
│   │   └── tofu.tfvars          # OpenTofu variables (env, chart registry)
│   ├── app-of-apps.yaml         # ArgoCD Application: orchestrator + AppProfiles + Tenants
│   └── tenants/
│       └── dev-tenant.yaml      # gtn-demo Tenant CR
└── README.md
```

---

## Prerequisites

- [microk8s](https://microk8s.io/) or any Kubernetes ≥ 1.27
- `kubectl`, `helm`, `jq`, `openssl`, `curl` available on the machine running the bootstrap
- Access to `registry.opencode.de` (OpenDesk chart registry)

You need both this repo **and** the [gentian-os](https://github.com/gentian-org/gentian-os) repo checked out. The bootstrap script auto-detects `gentian-os` as a sibling directory or you can set `GENTIAN_OS_DIR`.

---

## Fresh cluster bootstrap

```bash
# Clone both repos side by side
git clone https://github.com/gentian-org/gentian-os
git clone https://github.com/gentian-org/gentian-deployments

# Run the bootstrap script (prompts for credentials interactively)
bash gentian-deployments/dev/bootstrap/install.sh
```

The bootstrap performs 13 ordered steps:

| Step | Action |
|------|--------|
| 0 | Pre-flight checks |
| 1 | Install CLI tools (`tofu`, `bao`) |
| 2 | Create Kubernetes namespaces |
| 3 | Install External Secrets Operator |
| 4 | Install ArgoCD + AppProject |
| 5 | Configure ArgoCD OCI registry secrets |
| 6 | Deploy OpenBao transit seal instance |
| 7 | Init transit instance + auto-unseal secret |
| 8 | Apply remaining ArgoCD bootstrap Applications |
| 9 | Initialize primary OpenBao |
| 10 | Configure OpenBao via Tofu (KV engine, K8s auth, ESO policy) |
| 11 | Seed application secrets |
| 12 | Apply kernel ApplicationSet → ArgoCD syncs kernel services |
| 13 | Apply `app-of-apps.yaml` → deploy orchestrator + AppProfiles + Tenants |

### Credentials

The following environment variables are prompted interactively if not pre-exported:

| Variable | Description |
|----------|-------------|
| `MASTER_PASSWORD` | HMAC master secret for deriving all application passwords |
| `OD_PRIVATE_REGISTRY_USERNAME` | `registry.opencode.de` username |
| `OD_PRIVATE_REGISTRY_PASSWORD` | `registry.opencode.de` password or token |
| `OD_SMTP_RELAY_USERNAME` | SMTP relay username (e.g. Gmail address) |
| `OD_SMTP_RELAY_PASSWORD` | SMTP relay password (e.g. Gmail App Password) |

### Optional environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GENTIAN_OS_DIR` | `../../gentian-os` (auto-detected) | Path to gentian-os checkout |
| `NODE_IP` | auto-detected | Cluster node IP for access info output |
| `SKIP_TOOLS` | `0` | Set to `1` to skip CLI tool installation |
| `OPENBAO_INIT_FILE` | `/tmp/openbao-init.json` | File to save OpenBao init keys |

---

## Day-2 operations

### Apply app-of-apps manually (after cluster is running)

```bash
kubectl apply -f dev/app-of-apps.yaml
```

### Add a new Tenant

1. Create a new file in `dev/tenants/`
2. Commit and push
3. ArgoCD auto-syncs the `gentian-os` Application

### Update the orchestrator version

1. Edit the `targetRevision` in `dev/app-of-apps.yaml` (Source 1)
2. Commit and push

---

## Architecture

See [gentian-os docs/architecture.md](https://github.com/gentian-org/gentian-os/blob/develop/docs/architecture.md) for the full system architecture.

