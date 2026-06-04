# Dev kernel Helm overrides

`values-dev.yaml` is merged by `dev/app-of-apps.yaml` into the `gentian-os` operator chart.

## TLS (staging)

Dev clusters should use Let's Encrypt **staging** at the origin to avoid production ACME rate limits during reinstalls:

1. In `gentian-os/install.env` on the install host: `ACME_ENV=staging`
2. Apply staging ClusterIssuers: `./update.sh --acme-issuers` (or fresh `install.sh`)
3. This file sets `tenantDNS01ClusterIssuer: letsencrypt-staging-dns01-cloudflare` — sync via Argo after commit.

Staging certificates are not trusted by browsers (expected for dev).

For **proxied** Cloudflare hostnames (`meet.demo.desk.gentian.org`), also enable **Total TLS** on the zone so the edge presents a valid cert. See [multi-tenancy TLS §3](https://github.com/gentian-org/gentian-os/blob/develop/docs/design/multi-tenancy.md).

## Operator image

`image.tag: develop` is updated by Argo CD Image Updater (`image-updater.yaml`).
