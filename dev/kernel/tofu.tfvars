# tofu.tfvars — OpenTofu variable overrides for the dev environment
#
# Used by kernel/tofu/tenant/infra-workspaces/ when deploying
# Pattern-B (Tofu-managed) Helm releases.
#
# Note: sensitive variables (registry_username, registry_password) are
# injected at runtime from OpenBao ExternalSecrets (see
# kernel/services/tofu/manifests/dev/externalsecrets.yaml).

env           = "dev"
chart_registry = "registry.opencode.de/bmi/opendesk/components"
