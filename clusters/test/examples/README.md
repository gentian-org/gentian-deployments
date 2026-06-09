# Tenant examples

These manifests are **not** deployed automatically. Fresh installs leave
`clusters/<cluster>/tenants/` empty until a cluster admin provisions tenants.

Copy an example into the live tenant path when you are ready:

```bash
cp -a clusters/test/examples/demo clusters/test/tenants/demo
# edit clusters/test/tenants/<tenant>/dev/tenant.yaml as needed
kubectl gentian tenants deploy demo
```

Or scaffold from the example in one step (copies into `tenants/` and commits to Git):

```bash
kubectl gentian tenants deploy demo
```

The `gentian-tenants` ApplicationSet only watches `clusters/<cluster>/tenants/*/<stage>`.

`kubectl gentian tenants list` shows example templates as `ACTIVE=no` until you
deploy them into `tenants/`.
