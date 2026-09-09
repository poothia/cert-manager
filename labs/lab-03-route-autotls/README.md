# Lab 3: Annotate Your Own Route for Auto-TLS

## Objective

Use the openshift-routes controller to automatically issue and attach a TLS certificate to an OpenShift Route using annotations -- no manual cert extraction needed.

## Prerequisites

- Lab 1 completed (ca-issuer exists)
- Lab 2 completed (workshop-demo namespace and secure-app deployment exist)
- Demo 3 completed (openshift-routes controller is installed)

## Steps

### Step 1 -- Verify the openshift-routes controller is running

```bash
oc get pods -n cert-manager | grep openshift-routes
# Should show a Running pod
```

### Step 2 -- Apply the annotated Route

Edit `00-route-annotated.yaml` to set the correct `host` for your cluster:

```bash
oc apply -f 00-route-annotated.yaml
```

### Step 3 -- Watch the magic happen

```bash
# Watch the Route -- the TLS section will be populated automatically
oc get route auto-tls-app -n workshop-demo -o yaml -w

# You can also watch the Certificate and CertificateRequest resources:
oc get certificate -n workshop-demo -w
oc get certificaterequest -n workshop-demo
```

Within 30-60 seconds, the Route's `spec.tls.certificate` and `spec.tls.key` fields should be populated automatically by the openshift-routes controller.

### Step 4 -- Verify

```bash
ROUTE_HOST=$(oc get route auto-tls-app -n workshop-demo -o jsonpath='{.spec.host}')

# Extract the CA for verification
oc get secret root-ca-secret -n cert-manager \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/workshop-ca.crt

curl --cacert /tmp/workshop-ca.crt "https://${ROUTE_HOST}"
```

### Key Annotations Reference

| Annotation | Required | Default | Description |
|------------|----------|---------|-------------|
| `cert-manager.io/issuer-name` | Yes | -- | Name of the Issuer or ClusterIssuer |
| `cert-manager.io/issuer-kind` | No | `Issuer` | `Issuer` or `ClusterIssuer` |
| `cert-manager.io/duration` | No | `2160h` (90d) | Certificate validity period |
| `cert-manager.io/renew-before` | No | 1/3 of duration | When to trigger renewal |
| `cert-manager.io/common-name` | No | -- | CN for the certificate |
| `cert-manager.io/alt-names` | No | -- | Comma-separated extra SANs |

## Cleanup

```bash
oc delete route auto-tls-app -n workshop-demo
```
