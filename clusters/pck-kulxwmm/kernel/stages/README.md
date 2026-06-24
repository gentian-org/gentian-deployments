# Kernel stage placeholders

This cluster is **production-only** (`prod`). Active kernel config lives as
sibling files in `../`:

- `values-prod.yaml`
- `image-updater-prod.yaml`
- `app-of-apps-prod.yaml`

The `dev/` and `staging/` directories here are placeholders only. To add a
stage, create the corresponding files in `../` (not inside these folders):

- `values-<stage>.yaml`
- `image-updater-<stage>.yaml`
- `app-of-apps-<stage>.yaml` (optional)

Then bootstrap or re-apply Argo with `GENTIAN_DEPLOYMENTS_STAGE=<stage>`.
