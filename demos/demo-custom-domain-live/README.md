# LIVE DEMO: Two Layers of TLS Automation with cert-manager

> Tailored for cluster: `cluster-z8n9x.dyn.redhatworkshops.io`
> OCP 4.22.11 | cert-manager Operator v1.20.0
> ACME Issuer: `acme-bifrost-production-ddns` (Google Trust Services)
>
> **100% Red Hat supported** -- uses native `externalCertificate` on Routes
> (GA since OCP 4.22, no third-party controllers needed)

---

## The Story

This demo has two acts:

**Act 1 -- "The invisible guardian"**
Show that cert-manager is ALREADY securing the entire cluster -- every Route
gets a Google-trusted certificate automatically via a wildcard cert. Most
people on this cluster don't even know cert-manager exists.

**Act 2 -- "The dedicated certificate"**
A service needs its own identity -- maybe for compliance, maybe because the
domain is external. You create a Certificate resource, and the Route
references the Secret directly via `externalCertificate`. Fully supported,
no community add-ons.

---

## How `externalCertificate` works (the Red Hat supported way)

On OCP 4.22, the `RouteExternalCertificate` feature is GA and always enabled.
A Route can reference a TLS Secret directly instead of embedding certs inline:

```yaml
spec:
  tls:
    termination: edge
    externalCertificate:
      name: my-tls-secret    # <-- references a kubernetes.io/tls Secret
```

The OpenShift router reads the Secret and serves the certificate. When
cert-manager renews the cert (updating the Secret), the router picks up
the new cert automatically. Three resources, fully declarative:

```
Certificate (cert-manager)  -->  Secret (auto-created)  <--  Route (externalCertificate)
```

One RBAC requirement: the router service account (`openshift-ingress:router`)
needs read access to the Secret.

---

## Pre-flight

No pre-flight installation needed. Everything is built into OCP 4.22 +
the cert-manager operator that's already installed.

Verify:

```bash
# cert-manager is running
oc get pods -n cert-manager

# ACME issuer is ready
oc get clusterissuer acme-bifrost-production-ddns

# externalCertificate field exists
oc explain route.spec.tls.externalCertificate
```

---

## ACT 1: The Invisible Guardian (~4 min)

**What you say**: "Before we do anything, let me show you something.
cert-manager is already working on this cluster. You just can't see it."

### Step 1: Deploy an app and create a plain Route

```bash
oc new-project custom-domain-demo

oc create deployment web-app \
  --image=registry.access.redhat.com/ubi9/httpd-24:latest \
  -n custom-domain-demo

oc expose deployment web-app --port=8080 -n custom-domain-demo

oc rollout status deployment/web-app -n custom-domain-demo --timeout=60s
```

Create a basic Route (no cert-manager involvement):

```bash
oc create route edge web-app \
  --service=web-app \
  --insecure-policy=Redirect \
  -n custom-domain-demo
```

### Step 2: Show it's already secured with a Google-trusted cert

```bash
ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')

# Inspect the certificate the router is serving
echo | openssl s_client -servername "${ROUTE_HOST}" \
  -connect "$(oc get route web-app -n custom-domain-demo \
    -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'):443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

**Expected output**:
```
subject=CN=*.apps.cluster-z8n9x.dyn.redhatworkshops.io     <-- WILDCARD
issuer=C=US, O=Google Trust Services, CN=WR1
...
DNS:*.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

**What you say**: "Green padlock, Google-trusted certificate -- and we didn't
configure any TLS. This is cert-manager working at the infrastructure level."

### Step 3: Reveal the wildcard Certificate resource

```bash
oc get certificate -n openshift-ingress

oc get secret cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -issuer -dates
```

```bash
# Show the auto-renewal schedule
oc get certificate cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='Expires: {.status.notAfter}  Renews at: {.status.renewalTime}{"\n"}'
```

> "cert-manager issued this wildcard and will renew it automatically on
> November 20th. No tickets, no calendar reminders. That's layer one."

**Transition**: "But what happens when a service needs its own certificate?"

---

## ACT 2: The Dedicated Certificate (~6 min)

### Step 4: Create a Certificate resource

**What you say**: "Here's where cert-manager shines at the application level.
We create a Certificate resource -- it tells cert-manager what hostname we
need, which issuer to use, and where to store the result."

```bash
ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')

cat <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-app-cert
  namespace: custom-domain-demo
spec:
  secretName: web-app-tls
  dnsNames:
    - ${ROUTE_HOST}
  issuerRef:
    name: acme-bifrost-production-ddns
    kind: ClusterIssuer
    group: cert-manager.io
EOF
```

### Step 5: Watch cert-manager issue the certificate

```bash
oc get certificate web-app-cert -n custom-domain-demo -w
```

**While waiting (~30-60 sec), explain the ACME flow**:
> "cert-manager just created an ACME Order with Google's CA. Google says
> 'prove you own this domain' via a DNS challenge. cert-manager is adding
> a TXT record to DNS right now. Once Google verifies it, the cert is
> signed and stored in a Secret. All automatic."

Watch for `READY = True`:

```bash
oc get certificate web-app-cert -n custom-domain-demo
# READY   SECRET
# True    web-app-tls
```

### Step 6: Grant the router access to the Secret

**What you say**: "The router needs read access to our Secret -- this is
standard OpenShift RBAC. Two commands."

```bash
oc create role secret-reader \
  --verb=get,list,watch \
  --resource=secrets \
  --resource-name=web-app-tls \
  -n custom-domain-demo

oc create rolebinding router-secret-reader \
  --role=secret-reader \
  --serviceaccount=openshift-ingress:router \
  -n custom-domain-demo
```

### Step 7: Update the Route to use `externalCertificate`

**What you say**: "Now the key part. We tell the Route to use our
cert-manager Secret instead of the default wildcard. One field:
`externalCertificate`."

```bash
oc delete route web-app -n custom-domain-demo

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: custom-domain-demo
spec:
  host: ${ROUTE_HOST}
  to:
    kind: Service
    name: web-app
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
    externalCertificate:
      name: web-app-tls
EOF
```

**Pause and point at the YAML**:
> "Look at `externalCertificate.name: web-app-tls`. That's the Secret that
> cert-manager created. The router reads it directly. When cert-manager
> renews the cert and updates the Secret, the router picks up the new cert
> automatically. No restart, no manual intervention."

### Step 8: The payoff -- dedicated certificate

```bash
sleep 5

ROUTER_IP=$(nslookup "$(oc get route web-app -n custom-domain-demo \
  -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')" 2>/dev/null \
  | grep "Address:" | tail -1 | awk '{print $2}')

echo "=== BEFORE: Shared wildcard ==="
oc get secret cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -ext subjectAltName

echo ""
echo "=== AFTER: Dedicated cert (what the Route now serves) ==="
echo | openssl s_client -servername "${ROUTE_HOST}" \
  -connect "${ROUTER_IP}:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

**Expected output**:
```
=== BEFORE: Shared wildcard ===
subject=CN=*.apps.cluster-z8n9x.dyn.redhatworkshops.io
    DNS:*.apps.cluster-z8n9x.dyn.redhatworkshops.io

=== AFTER: Dedicated cert (what the Route now serves) ===
issuer=C=US, O=Google Trust Services, CN=WR1
notBefore=Sep  9 ...
notAfter=Dec  8 ...
    DNS:web-app-custom-domain-demo.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

**What you say**:
> "The SAN changed. Before: `*.apps...` -- the shared wildcard. After:
> `web-app-custom-domain-demo.apps...` -- a dedicated cert issued
> specifically for this service. Same Google trust, but its own identity.
>
> And this is 100% Red Hat supported. Native OpenShift `externalCertificate`
> plus the cert-manager operator. No community controllers, no Helm charts,
> no unsupported components."

---

## RECAP (what you tell the audience)

> "Two layers of cert-manager on OpenShift:
>
> **Layer 1 -- Infrastructure**: cert-manager issues and auto-renews the
> cluster wildcard. Every route gets TLS by default.
>
> **Layer 2 -- Application**: Create a Certificate resource, point your Route
> at the Secret via `externalCertificate`. Dedicated, Google-trusted cert.
> Automatic renewal. Fully supported.
>
> Three resources. Zero manual cert handling. Zero expiry risk."

---

## The Three Resources (summary for the audience)

```yaml
# 1. Certificate -- tells cert-manager what to issue
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-app-cert
spec:
  secretName: web-app-tls
  dnsNames: ["my-app.example.com"]
  issuerRef:
    name: my-issuer
    kind: ClusterIssuer

# 2. Secret -- created automatically by cert-manager (don't touch)
# Contains: tls.crt, tls.key, ca.crt

# 3. Route -- references the Secret
apiVersion: route.openshift.io/v1
kind: Route
spec:
  tls:
    termination: edge
    externalCertificate:
      name: web-app-tls    # <-- points to the cert-manager Secret
```

---

## Cleanup

```bash
oc delete project custom-domain-demo
```

---

## Timing

| Step | Duration |
|------|----------|
| Act 1: Steps 1-3 (show wildcard) | ~3 min |
| Transition | 30 sec |
| Act 2: Steps 4-5 (create Certificate, wait for ACME) | ~2 min |
| Act 2: Steps 6-7 (RBAC + Route) | ~1 min |
| Act 2: Step 8 (verify) | ~1 min |
| Recap | 1 min |
| **Total** | **~9 min** |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Certificate stuck `Ready=False` | `oc describe certificate -n custom-domain-demo` -- check ACME errors |
| Route shows `ExternalCertificateValidationFailed` | RBAC missing -- verify Role and RoleBinding grant `get,list,watch` on the Secret to `openshift-ingress:router` |
| Route serving wildcard instead of dedicated cert | Router may need a few seconds to reload; also verify the Route has `externalCertificate` set (not `certificate` inline) |
| DNS not resolving | This cluster uses `*.apps.cluster-z8n9x.dyn.redhatworkshops.io` wildcard DNS. Use `openssl s_client --resolve` or `--servername` to test from outside. |
