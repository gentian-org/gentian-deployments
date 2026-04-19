#!/usr/bin/env bash
# =============================================================================
# install.sh — Fresh-cluster bootstrap for the Gentian homelab server stack
# =============================================================================
# Installs and configures every component in the correct order:
#   1. CLI tools (tofu, bao)
#   2. Kubernetes namespaces
#  2b. cert-manager ClusterIssuer + Cloudflare DNS solver + wildcard Certificate
#   3. External Secrets Operator (ESO) via Helm
#   4. ArgoCD + AppProject
#   5. ArgoCD OCI registry secrets
#   6. Deploy OpenBao transit seal instance
#   7. Init transit instance + autounseal k8s Secret
#   8. Apply remaining ArgoCD bootstrap Applications
#   9. Initialize primary OpenBao (transit auto-unseal)
#  10. Configure OpenBao via Tofu (KV engine, K8s auth, ESO policy)
#  11. Seed all application secrets (seed-openbao.sh)
#  12. Apply kernel bootstrap ApplicationSet → ArgoCD syncs the kernel stack
#  13. Apply app-of-apps.yaml → deploy orchestrator + AppProfiles + Tenants
#  14. Install AppCatalogue CRD + kubectl-gentian plugin (App Store)
#
# Required environment variables (prompted interactively if not pre-exported):
#   MASTER_PASSWORD                — master password for HMAC-derived secrets
#   OD_PRIVATE_REGISTRY_USERNAME   — registry.opencode.de username
#   OD_PRIVATE_REGISTRY_PASSWORD   — registry.opencode.de password or token
#   OD_SMTP_RELAY_USERNAME         — SMTP relay username (e.g. Gmail address)
#   OD_SMTP_RELAY_PASSWORD         — SMTP relay password (e.g. Gmail App Password)
#   ACME_EMAIL                     — email for Let's Encrypt ACME registration
#   CLOUDFLARE_API_TOKEN           — Cloudflare API token (Zone:DNS:Edit scope)
#
# Optional environment variables:
#   GENTIAN_OS_DIR    — path to gentian-os checkout (default: auto-detected)
#   NODE_IP           — cluster node IP (default: auto-detected)
#   SKIP_TOOLS        — set to "1" to skip CLI tool installation
#   OPENBAO_INIT_FILE — path to save OpenBao init keys (default: /tmp/openbao-init.json)
#   BAO_PORT_FORWARD  — local port for OpenBao port-forward (default: 8200)#   TENANT_DOMAIN     — tenant domain for wildcard cert (default: desk.gentian.org)#
# Usage:
#   ./install.sh
#   # — or — pre-export any subset of the required variables to skip prompts:
#   export MASTER_PASSWORD="..."
#   export OD_PRIVATE_REGISTRY_USERNAME="..."
#   ./install.sh
# =============================================================================

set -euo pipefail

# ─── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
banner()  { echo -e "\n${CYAN}══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════════════${NC}\n"; }

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# DEPLOY_DIR = gentian-deployments/dev/
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Auto-detect gentian-os checkout relative to this repo, or use GENTIAN_OS_DIR override
if [[ -z "${GENTIAN_OS_DIR:-}" ]]; then
    # Assumed layout: both repos are siblings → ../../gentian-os from bootstrap/
    CANDIDATE="$(cd "${SCRIPT_DIR}/../../.." && pwd)/gentian-os"
    if [[ -d "${CANDIDATE}/kernel" ]]; then
        GENTIAN_OS_DIR="${CANDIDATE}"
    else
        error "Cannot auto-detect gentian-os directory. Set GENTIAN_OS_DIR env var."
        exit 1
    fi
fi
info "Using gentian-os at: ${GENTIAN_OS_DIR}"

# =============================================================================
# Prompt for any required credentials that were not pre-exported
# =============================================================================
prompt_credentials() {
    local prompted=0

    if [[ -z "${MASTER_PASSWORD:-}" ]]; then
        read -rp "  MASTER_PASSWORD (HMAC master secret): " MASTER_PASSWORD; echo ""
        export MASTER_PASSWORD
        prompted=1
    fi

    if [[ -z "${OD_PRIVATE_REGISTRY_USERNAME:-}" ]]; then
        read -rp  "  OD_PRIVATE_REGISTRY_USERNAME (registry.opencode.de): " OD_PRIVATE_REGISTRY_USERNAME; echo ""
        export OD_PRIVATE_REGISTRY_USERNAME
        prompted=1
    fi

    if [[ -z "${OD_PRIVATE_REGISTRY_PASSWORD:-}" ]]; then
        read -rp "  OD_PRIVATE_REGISTRY_PASSWORD (registry.opencode.de token): " OD_PRIVATE_REGISTRY_PASSWORD; echo ""
        export OD_PRIVATE_REGISTRY_PASSWORD
        prompted=1
    fi

    if [[ -z "${OD_SMTP_RELAY_USERNAME:-}" ]]; then
        read -rp  "  OD_SMTP_RELAY_USERNAME (e.g. user@gmail.com): " OD_SMTP_RELAY_USERNAME; echo ""
        export OD_SMTP_RELAY_USERNAME
        prompted=1
    fi

    if [[ -z "${OD_SMTP_RELAY_PASSWORD:-}" ]]; then
        read -rp "  OD_SMTP_RELAY_PASSWORD (e.g. Gmail App Password): " OD_SMTP_RELAY_PASSWORD; echo ""
        export OD_SMTP_RELAY_PASSWORD
        prompted=1
    fi

    if [[ -z "${ACME_EMAIL:-}" ]]; then
        read -rp "  ACME_EMAIL (Let's Encrypt registration email): " ACME_EMAIL; echo ""
        export ACME_EMAIL
        prompted=1
    fi

    if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        read -rp "  CLOUDFLARE_API_TOKEN (Zone:DNS:Edit): " CLOUDFLARE_API_TOKEN; echo ""
        export CLOUDFLARE_API_TOKEN
        prompted=1
    fi

    if [[ "$prompted" -eq 1 ]]; then
        echo ""
        read -rp "  Save credentials to ${GENTIAN_CONFIG_FILE} for future runs? [yes/no]: " save_creds
        if [[ "$save_creds" == "yes" ]]; then
            mkdir -p "$(dirname "${GENTIAN_CONFIG_FILE}")"
            chmod 700 "$(dirname "${GENTIAN_CONFIG_FILE}")"
            cat > "${GENTIAN_CONFIG_FILE}" <<EOF
# Gentian bootstrap credentials — generated by install.sh
# Delete this file to be prompted again.
export MASTER_PASSWORD="${MASTER_PASSWORD}"
export OD_PRIVATE_REGISTRY_USERNAME="${OD_PRIVATE_REGISTRY_USERNAME}"
export OD_PRIVATE_REGISTRY_PASSWORD="${OD_PRIVATE_REGISTRY_PASSWORD}"
export OD_SMTP_RELAY_USERNAME="${OD_SMTP_RELAY_USERNAME}"
export OD_SMTP_RELAY_PASSWORD="${OD_SMTP_RELAY_PASSWORD}"
export ACME_EMAIL="${ACME_EMAIL}"
export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}"
EOF
            chmod 600 "${GENTIAN_CONFIG_FILE}"
            success "Credentials saved to ${GENTIAN_CONFIG_FILE}"
        fi
    fi
}

# ─── Config file (saves credentials across re-runs) ─────────────────────────
GENTIAN_CONFIG_FILE="${GENTIAN_CONFIG_FILE:-${HOME}/.gentian/config}"
if [[ -f "${GENTIAN_CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${GENTIAN_CONFIG_FILE}"
fi

# ─── Runtime defaults ─────────────────────────────────────────────────────────
OPENBAO_INIT_FILE="${OPENBAO_INIT_FILE:-/tmp/openbao-init.json}"
BAO_PORT_FORWARD="${BAO_PORT_FORWARD:-8200}"

# ─── Versions ────────────────────────────────────────────────────────────────
TOFU_VERSION="1.9.0"
BAO_VERSION="2.5.1"

# ─── Tool versions ───────────────────────────────────────────────────────────
ESO_CHART_VERSION="4.5.0"   # external-secrets chart version

# =============================================================================
# 0. Pre-flight checks
# =============================================================================
check_prereqs() {
    banner "Pre-flight checks"

    local missing=0

    for cmd in kubectl helm jq openssl curl; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Required command not found: $cmd"
            missing=$((missing + 1))
        else
            success "$cmd found"
        fi
    done

    if [[ -z "${MASTER_PASSWORD:-}" ]]; then
        error "MASTER_PASSWORD is not set"
        missing=$((missing + 1))
    else
        success "MASTER_PASSWORD set"
    fi

    if [[ -z "${OD_PRIVATE_REGISTRY_USERNAME:-}" ]]; then
        error "OD_PRIVATE_REGISTRY_USERNAME is not set"
        missing=$((missing + 1))
    else
        success "OD_PRIVATE_REGISTRY_USERNAME set"
    fi

    if [[ -z "${OD_PRIVATE_REGISTRY_PASSWORD:-}" ]]; then
        error "OD_PRIVATE_REGISTRY_PASSWORD is not set"
        missing=$((missing + 1))
    else
        success "OD_PRIVATE_REGISTRY_PASSWORD set"
    fi

    if [[ -z "${OD_SMTP_RELAY_USERNAME:-}" ]]; then
        error "OD_SMTP_RELAY_USERNAME is not set (SMTP relay username, e.g. Gmail address)"
        missing=$((missing + 1))
    else
        success "OD_SMTP_RELAY_USERNAME set"
    fi

    if [[ -z "${OD_SMTP_RELAY_PASSWORD:-}" ]]; then
        error "OD_SMTP_RELAY_PASSWORD is not set (SMTP relay password, e.g. Gmail App Password)"
        missing=$((missing + 1))
    else
        success "OD_SMTP_RELAY_PASSWORD set"
    fi

    if [[ -z "${ACME_EMAIL:-}" ]]; then
        error "ACME_EMAIL is not set (Let's Encrypt registration email)"
        missing=$((missing + 1))
    else
        success "ACME_EMAIL set"
    fi

    if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        error "CLOUDFLARE_API_TOKEN is not set (Cloudflare API token with Zone:DNS:Edit scope)"
        missing=$((missing + 1))
    else
        success "CLOUDFLARE_API_TOKEN set"
    fi

    if [[ "$missing" -gt 0 ]]; then
        error "$missing prerequisite(s) missing. Aborting."
        exit 1
    fi

    # Auto-detect node IP if not supplied
    if [[ -z "${NODE_IP:-}" ]]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        info "Auto-detected NODE_IP: $NODE_IP"
    fi
    export NODE_IP

    success "All pre-flight checks passed."
}

# =============================================================================
# 1. Install CLI tools
# =============================================================================
install_tools() {
    if [[ "${SKIP_TOOLS:-0}" == "1" ]]; then
        warn "SKIP_TOOLS=1 — skipping CLI tool installation."
        return
    fi

    banner "Step 1 — Installing CLI tools"

    # ── OpenTofu ──────────────────────────────────────────────────────────
    if command -v tofu &>/dev/null && tofu version 2>/dev/null | grep -q "$TOFU_VERSION"; then
        success "tofu $TOFU_VERSION already installed."
    else
        info "Installing OpenTofu v${TOFU_VERSION}..."
        local arch
        arch=$(uname -m); [[ "$arch" == "x86_64" ]] && arch="amd64"
        local pkg="tofu_${TOFU_VERSION}_linux_${arch}.deb"
        local url="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/${pkg}"
        curl -fsSL "$url" -o "/tmp/${pkg}"
        sudo dpkg -i "/tmp/${pkg}"
        rm -f "/tmp/${pkg}"
        success "tofu $TOFU_VERSION installed."
    fi

    # ── OpenBao CLI ────────────────────────────────────────────────────────
    if command -v bao &>/dev/null && bao version 2>/dev/null | grep -q "$BAO_VERSION"; then
        success "bao $BAO_VERSION already installed."
    else
        info "Installing OpenBao CLI v${BAO_VERSION}..."
        local arch
        arch=$(uname -m); [[ "$arch" == "x86_64" ]] && arch="amd64"
        local pkg="openbao_${BAO_VERSION}_linux_${arch}.deb"
        local url="https://github.com/openbao/openbao/releases/download/v${BAO_VERSION}/${pkg}"
        curl -fsSL "$url" -o "/tmp/${pkg}"
        sudo dpkg -i "/tmp/${pkg}"
        rm -f "/tmp/${pkg}"
        success "bao $BAO_VERSION installed."
    fi
}

# =============================================================================
# 2. Create namespaces (idempotent)
# =============================================================================
create_namespaces() {
    banner "Step 2 — Creating namespaces"

    local namespaces=(openbao external-secrets argocd tofu-system gentian-dev gentian-infra-dev gentian-system cnpg-system platform-kernel)
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null; then
            success "Namespace $ns already exists."
        else
            kubectl create namespace "$ns"
            success "Namespace $ns created."
        fi
    done
}

# =============================================================================
# 2b. Set up cert-manager ClusterIssuer and Cloudflare DNS solver
# =============================================================================
setup_cert_manager() {
    banner "Step 2b — Setting up cert-manager TLS certificate issuance"

    local cm_ns="cert-manager"

    # Ensure cert-manager namespace exists (may be created by addon/Helm)
    if ! kubectl get namespace "${cm_ns}" &>/dev/null; then
        warn "cert-manager namespace does not exist. Ensure cert-manager is installed"
        warn "(e.g. 'microk8s enable cert-manager' or Helm install)."
        return 1
    fi

    # Create or update the Cloudflare API token secret
    if kubectl get secret cloudflare-api-token -n "${cm_ns}" &>/dev/null; then
        success "Secret cloudflare-api-token already exists in ${cm_ns}."
    else
        info "Creating cloudflare-api-token secret in ${cm_ns}..."
        kubectl create secret generic cloudflare-api-token \
            -n "${cm_ns}" \
            --from-literal=api-token="${CLOUDFLARE_API_TOKEN}"
        success "cloudflare-api-token secret created."
    fi

    # Create the ClusterIssuer
    info "Applying ClusterIssuer letsencrypt-prod..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${ACME_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
EOF
    success "ClusterIssuer letsencrypt-prod applied."

    # Wait for the ClusterIssuer to become ready
    info "Waiting for ClusterIssuer to register with ACME..."
    local retries=0
    while [[ $retries -lt 30 ]]; do
        local ready
        ready=$(kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [[ "$ready" == "True" ]]; then
            success "ClusterIssuer letsencrypt-prod is ready."
            break
        fi
        sleep 2
        retries=$((retries + 1))
    done
    if [[ $retries -ge 30 ]]; then
        warn "ClusterIssuer did not become ready within 60s. Check: kubectl describe clusterissuer letsencrypt-prod"
    fi

    # Create a wildcard Certificate for the dev namespace.
    # All ingresses (nubus, nextcloud, ICS) reference the resulting Secret
    # ("wildcard-tls") so they serve valid certs without per-chart cert-manager.
    local domain="${TENANT_DOMAIN:-desk.gentian.org}"
    local ns="${DEV_NAMESPACE:-gentian-dev}"
    info "Creating wildcard Certificate for *.${domain} in ${ns}..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls
  namespace: ${ns}
spec:
  secretName: wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "${domain}"
    - "*.${domain}"
EOF
    success "Wildcard Certificate CR applied in ${ns}."

    # Wait for the Certificate to be issued (DNS-01 can take a few minutes).
    info "Waiting for wildcard-tls certificate to be Ready (up to 5 min)..."
    if kubectl wait --for=condition=Ready certificate/wildcard-tls \
        -n "${ns}" --timeout=300s 2>/dev/null; then
        success "Wildcard TLS certificate issued successfully."
    else
        warn "Certificate not ready after 5 min. Check: kubectl describe certificate wildcard-tls -n ${ns}"
    fi
}

# =============================================================================
# 3. Install External Secrets Operator via Helm
# =============================================================================
install_eso() {
    banner "Step 3 — Installing External Secrets Operator"

    if helm status external-secrets -n external-secrets &>/dev/null; then
        success "ESO already installed. Skipping."
        return
    fi

    info "Adding external-secrets Helm repo..."
    helm repo add external-secrets https://charts.external-secrets.io --force-update
    helm repo update

    info "Installing external-secrets chart..."
    helm install external-secrets external-secrets/external-secrets \
        -n external-secrets \
        -f "${GENTIAN_OS_DIR}/kernel/eso/values.yaml" \
        --wait \
        --timeout 5m

    success "ESO installed."
}

# =============================================================================
# 4. Install ArgoCD + AppProject
# =============================================================================
install_argocd() {
    banner "Step 4 — Installing ArgoCD"

    if kubectl get deployment argocd-server -n argocd &>/dev/null; then
        success "ArgoCD already installed. Skipping install-argocd.sh."
    else
        info "Running install-argocd.sh..."
        bash "${GENTIAN_OS_DIR}/scripts/install-argocd.sh"
        success "ArgoCD installed."
    fi

    info "Applying ArgoCD AppProject..."
    kubectl apply -f "${GENTIAN_OS_DIR}/kernel/argocd/projects/gentian.yaml"
    success "AppProject applied."
}

# =============================================================================
# 5. Create ArgoCD OCI registry secrets
# =============================================================================
setup_argocd_repos() {
    banner "Step 5 — ArgoCD OCI registry secrets"

    info "Running create-argocd-oci-secrets.sh..."
    bash "${GENTIAN_OS_DIR}/scripts/create-argocd-oci-secrets.sh" \
        "$OD_PRIVATE_REGISTRY_USERNAME" \
        "$OD_PRIVATE_REGISTRY_PASSWORD"
    success "ArgoCD OCI secrets configured."
}

# =============================================================================
# 6. Deploy OpenBao transit seal instance
# =============================================================================
bootstrap_transit_app() {
    banner "Step 6 — OpenBao transit seal instance"

    # Create a placeholder secret so the pod can start on first boot.
    # The real unseal key is populated by init-openbao-transit.sh after init.
    if ! kubectl get secret openbao-transit-unseal -n openbao &>/dev/null; then
        info "Creating placeholder openbao-transit-unseal secret..."
        kubectl create secret generic openbao-transit-unseal \
            -n openbao \
            --from-literal=unseal-key=placeholder
        success "Placeholder secret created."
    fi

    kubectl apply -f "${GENTIAN_OS_DIR}/kernel/bootstrap/openbao-transit-application.yaml"
    success "Applied openbao-transit-application.yaml"

    info "Waiting for openbao-transit pod to become Running (up to 5 min)..."
    until kubectl get pods -n openbao -l app.kubernetes.io/instance=openbao-transit \
            --field-selector=status.phase=Running 2>/dev/null | grep -q openbao-transit; do
        echo -n "."
        sleep 5
    done
    echo ""
    success "openbao-transit pod is Running."
}

# =============================================================================
# 7. Init the transit instance and create the autounseal k8s Secret
# =============================================================================
init_openbao_transit() {
    banner "Step 7 — Transit instance init + autounseal Secret"
    bash "${GENTIAN_OS_DIR}/scripts/init-openbao-transit.sh"
}

# =============================================================================
# 8. Apply remaining ArgoCD bootstrap Applications
# =============================================================================
bootstrap_argocd_apps() {
    banner "Step 8 — ArgoCD bootstrap Applications"

    for app in openbao tofu-controller reloader globals; do
        kubectl apply -f "${GENTIAN_OS_DIR}/kernel/bootstrap/${app}-application.yaml"
        success "Applied ${app}-application.yaml"
    done

    info "Waiting for OpenBao pod to become Running (up to 5 min)..."
    until kubectl get pods -n openbao -l app.kubernetes.io/name=openbao \
            --field-selector=status.phase=Running 2>/dev/null | grep -q openbao; do
        echo -n "."
        sleep 5
    done
    echo ""
    success "OpenBao pod is Running."
}

# =============================================================================
# 9. Initialize primary OpenBao (transit auto-unseal)
# =============================================================================
init_openbao() {
    banner "Step 9 — OpenBao init"

    info "Waiting for openbao service to be created (up to 2 min)..."
    local i=0
    until kubectl get svc openbao -n openbao &>/dev/null; do
        echo -n "."
        sleep 5
        i=$((i + 5))
        [[ $i -lt 120 ]] || { error "Timed out waiting for openbao service."; exit 1; }
    done
    echo ""
    success "openbao service is ready."

    local BAO_SVC_IP
    BAO_SVC_IP=$(kubectl get svc openbao -n openbao -o jsonpath='{.spec.clusterIP}')
    local BAO_HTTP="http://${BAO_SVC_IP}:8200"

    local init_status
    init_status=$(curl -sf "${BAO_HTTP}/v1/sys/init" | jq -r '.initialized')

    if [[ "$init_status" == "true" ]]; then
        success "OpenBao already initialized."

        local sealed seal_type
        sealed=$(curl -sf "${BAO_HTTP}/v1/sys/seal-status" | jq -r '.sealed')
        seal_type=$(curl -sf "${BAO_HTTP}/v1/sys/seal-status" | jq -r '.type')

        if [[ "$sealed" == "true" ]]; then
            if [[ "$seal_type" == "transit" ]]; then
                warn "OpenBao is sealed but using transit — waiting for auto-unseal..."
                sleep 15
                sealed=$(curl -sf "${BAO_HTTP}/v1/sys/seal-status" | jq -r '.sealed')
                if [[ "$sealed" == "true" ]]; then
                    error "Transit auto-unseal did not complete. Check openbao-transit pod."
                    exit 1
                fi
                success "Transit auto-unseal completed."
            else
                warn "OpenBao is SEALED (Shamir). Provide the unseal key."
                read -rp "  Enter unseal key: " UNSEAL_KEY
                echo ""
                curl -sf -X PUT "${BAO_HTTP}/v1/sys/unseal" \
                    -H "Content-Type: application/json" \
                    -d "{\"key\": \"${UNSEAL_KEY}\"}" | jq .
                success "Unseal request sent."
            fi
        else
            success "OpenBao already unsealed (type: ${seal_type})."
        fi
        return
    fi

    # ── Detect seal type to choose correct init parameters ────────────────
    local seal_type_before
    seal_type_before=$(curl -sf "${BAO_HTTP}/v1/sys/seal-status" | jq -r '.type')

    if [[ "$seal_type_before" == "transit" ]]; then
        # ── Fresh init with transit seal (recovery keys, no manual unseal) ──
        info "Initializing OpenBao with transit seal (recovery_shares=1)..."
        local init_resp
        init_resp=$(curl -sf -X PUT "${BAO_HTTP}/v1/sys/init" \
            -H "Content-Type: application/json" \
            -d '{"recovery_shares": 1, "recovery_threshold": 1}')

        echo "$init_resp" > "${OPENBAO_INIT_FILE}"
        chmod 600 "${OPENBAO_INIT_FILE}"

        local recovery_key root_token
        recovery_key=$(echo "$init_resp" | jq -r '.recovery_keys_b64[0]')
        root_token=$(echo "$init_resp"   | jq -r '.root_token')

        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⚠  SAVE TO PASSWORD MANAGER (gentian/openbao-primary)       ║${NC}"
        echo -e "${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║  Recovery Key : ${recovery_key}${NC}"
        echo -e "${RED}║  Root Token   : ${root_token}${NC}"
        echo -e "${RED}║  (recovery key = emergency disaster-recovery only;            ║${NC}"
        echo -e "${RED}║   normal unsealing is automatic via transit)                  ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -rp "  Have you saved both values to your password manager? [yes/no]: " confirmed
        [[ "$confirmed" == "yes" ]] || { error "Aborted."; exit 1; }

        export BAO_TOKEN="$root_token"

        info "Waiting for transit auto-unseal (up to 30 s)..."
        local i=0
        until curl -sf "${BAO_HTTP}/v1/sys/seal-status" | jq -e '.sealed == false' >/dev/null 2>&1; do
            sleep 3; i=$((i + 3))
            [[ $i -lt 30 ]] || { error "Auto-unseal timed out."; exit 1; }
        done
        success "OpenBao initialized and auto-unsealed via transit."

    else
        # ── Fresh init with Shamir seal (fallback / migration scenario) ───
        info "Initializing OpenBao (1-of-1 Shamir key shares)..."
        local init_resp
        init_resp=$(curl -sf -X PUT "${BAO_HTTP}/v1/sys/init" \
            -H "Content-Type: application/json" \
            -d '{"secret_shares": 1, "secret_threshold": 1}')

        echo "$init_resp" > "${OPENBAO_INIT_FILE}"
        chmod 600 "${OPENBAO_INIT_FILE}"

        local unseal_key root_token
        unseal_key=$(echo "$init_resp" | jq -r '.keys_base64[0]')
        root_token=$(echo "$init_resp"  | jq -r '.root_token')

        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⚠  SAVE THESE TO PASSWORD MANAGER — will NOT be shown again ║${NC}"
        echo -e "${RED}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║  Unseal Key : ${unseal_key}${NC}"
        echo -e "${RED}║  Root Token : ${root_token}${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "  Keys also saved to: ${OPENBAO_INIT_FILE}"
        echo ""
        read -rp "  Have you saved both values to your password manager? [yes/no]: " confirmed
        [[ "$confirmed" == "yes" ]] || { error "Aborted."; exit 1; }

        info "Unsealing OpenBao..."
        curl -sf -X PUT "${BAO_HTTP}/v1/sys/unseal" \
            -H "Content-Type: application/json" \
            -d "{\"key\": \"${unseal_key}\"}" | jq .

        export BAO_ADDR="$BAO_HTTP"
        export BAO_TOKEN="$root_token"
        success "OpenBao initialized and unsealed (Shamir)."
    fi
}

# =============================================================================
# 10. Configure OpenBao via Tofu (KV engine, K8s auth, ESO policy)
# =============================================================================
run_tofu_openbao_init() {
    banner "Step 10 — OpenBao configuration via Tofu"

    # Resolve OpenBao address + token
    local BAO_SVC_IP
    BAO_SVC_IP=$(kubectl get svc openbao -n openbao -o jsonpath='{.spec.clusterIP}')
    export VAULT_ADDR="http://${BAO_SVC_IP}:8200"

    if [[ -z "${BAO_TOKEN:-}" ]]; then
        if [[ -f "${OPENBAO_INIT_FILE}" ]]; then
            BAO_TOKEN=$(jq -r '.root_token' "${OPENBAO_INIT_FILE}")
        else
            read -rp "  Enter OpenBao root token: " BAO_TOKEN
            echo ""
        fi
    fi
    export VAULT_TOKEN="$BAO_TOKEN"

    info "Running tofu apply in kernel/tofu/platform/openbao-init/..."
    pushd "${GENTIAN_OS_DIR}/kernel/tofu/platform/openbao-init" > /dev/null
        tofu init -backend=false
        tofu apply -auto-approve
    popd > /dev/null

    success "OpenBao configured via Tofu."
}

# =============================================================================
# 11. Seed application secrets
# =============================================================================
seed_secrets() {
    banner "Step 11 — Seeding application secrets"

    local BAO_SVC_IP
    BAO_SVC_IP=$(kubectl get svc openbao -n openbao -o jsonpath='{.spec.clusterIP}')
    export BAO_ADDR="http://${BAO_SVC_IP}:8200"

    if [[ -z "${BAO_TOKEN:-}" ]]; then
        if [[ -f "${OPENBAO_INIT_FILE}" ]]; then
            BAO_TOKEN=$(jq -r '.root_token' "${OPENBAO_INIT_FILE}")
        else
            read -rp "  Enter OpenBao root token: " BAO_TOKEN
            echo ""
        fi
    fi
    export BAO_TOKEN

    info "Running seed-openbao.sh..."
    bash "${GENTIAN_OS_DIR}/scripts/seed-openbao.sh" \
        "$MASTER_PASSWORD" \
        "$OD_PRIVATE_REGISTRY_USERNAME" \
        "$OD_PRIVATE_REGISTRY_PASSWORD" \
        "$OD_SMTP_RELAY_USERNAME" \
        "$OD_SMTP_RELAY_PASSWORD"

    success "All secrets seeded."
}

# =============================================================================
# 12. Apply kernel bootstrap ApplicationSet → ArgoCD syncs kernel services
# =============================================================================
bootstrap_kernel_appset() {
    banner "Step 12 — Applying kernel ApplicationSet"

    info "Applying all kernel bootstrap Applications from kernel/bootstrap/..."
    for f in "${GENTIAN_OS_DIR}"/kernel/bootstrap/*.yaml; do
        # Skip transit and globals — already applied in earlier steps
        case "$(basename "$f")" in
            openbao-transit-application.yaml) continue ;;
        esac
        kubectl apply -f "$f"
        success "Applied $(basename "$f")"
    done

    success "Kernel bootstrap Applications applied. ArgoCD will sync the kernel stack."
}

# =============================================================================
# 13. Apply app-of-apps.yaml → deploy orchestrator + AppProfiles + Tenants
# =============================================================================
deploy_app_of_apps() {
    banner "Step 13 — Deploying app-of-apps (orchestrator + AppProfiles + Tenants)"

    kubectl apply -f "${DEPLOY_DIR}/app-of-apps.yaml"
    success "app-of-apps.yaml applied."

    echo ""
    local argocd_pw bao_svc_ip portal_pw
    argocd_pw=$(kubectl get secret argocd-initial-admin-secret -n argocd \
                    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "<see argocd-initial-admin-secret>")
    bao_svc_ip=$(kubectl get svc openbao -n openbao -o jsonpath='{.spec.clusterIP}')
    portal_pw=$(curl -s \
                    -H "X-Vault-Token: ${BAO_TOKEN:-}" \
                    "http://${bao_svc_ip}:8200/v1/secret/data/gentian-os/kernel/identity/nubus" \
                2>/dev/null | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['data']['data']['admin_password'])" \
                2>/dev/null || echo "<see openbao: gentian-os/kernel/identity/nubus>")

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Bootstrap complete!                                     ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  ArgoCD URL   : https://${NODE_IP}:30443                  ║${NC}"
    echo -e "${GREEN}║  ArgoCD login : admin / ${argocd_pw}          ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Portal URL   : https://portal.desk.gentian.org          ║${NC}"
    echo -e "${GREEN}║  Portal login : Administrator / ${portal_pw} ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  ArgoCD is now syncing all applications."
    echo "  Monitor sync status:  kubectl get applications -n argocd"
}

# =============================================================================# 14. Install AppCatalogue CRD + kubectl-gentian plugin
# =============================================================================
install_app_store() {
    banner "Step 14 — Installing App Store CRD and kubectl-gentian plugin"

    local crd_file="${GENTIAN_OS_DIR}/config/crd/gentianos.io_appcatalogues.yaml"
    if [[ ! -f "${crd_file}" ]]; then
        warn "AppCatalogue CRD not found at ${crd_file} — skipping."
        return
    fi

    info "Applying AppCatalogue CRD..."
    kubectl apply -f "${crd_file}"
    success "AppCatalogue CRD installed. Query with: kubectl get appcatalogue default"

    local plugin="${GENTIAN_OS_DIR}/scripts/kubectl-gentian"
    if [[ -f "${plugin}" ]]; then
        if sudo install -m 755 "${plugin}" /usr/local/bin/kubectl-gentian 2>/dev/null; then
            success "kubectl-gentian plugin installed to /usr/local/bin. Use: kubectl gentian apps list"
        else
            local local_bin="${HOME}/.local/bin"
            mkdir -p "${local_bin}"
            install -m 755 "${plugin}" "${local_bin}/kubectl-gentian"
            success "kubectl-gentian plugin installed to ${local_bin} (no sudo). Use: kubectl gentian apps list"
            if [[ ":${PATH}:" != *":${local_bin}:"* ]]; then
                warn "${local_bin} is not in PATH. Add it: export PATH=\"\$PATH:${local_bin}\""
            fi
        fi
    else
        warn "kubectl-gentian script not found at ${plugin} — plugin not installed."
    fi
}

# =============================================================================# Main
# =============================================================================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Gentian Homelab — Fresh Cluster Bootstrap            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    prompt_credentials
    check_prereqs
    install_tools
    create_namespaces
    setup_cert_manager
    install_eso
    install_argocd
    setup_argocd_repos
    bootstrap_transit_app
    init_openbao_transit
    bootstrap_argocd_apps
    init_openbao
    run_tofu_openbao_init
    seed_secrets
    bootstrap_kernel_appset
    deploy_app_of_apps
    install_app_store
}

# Run main only when executed directly, not when sourced (e.g. for install_app_store)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
