# Demo: cert-manager Secures Your App on OpenShift

**Cluster**: `cluster-z8n9x.dyn.redhatworkshops.io` (OCP 4.22, cert-manager v1.20.0)
**Time**: ~9 minutes
**One takeaway**: cert-manager automatically issues and renews TLS certificates for your apps.

---

## Opening (say this before you touch the keyboard)

> "Every application needs TLS. Manually managing certificates --
> generating CSRs, tracking expiry dates, copying PEM files around --
> is a top cause of production outages.
>
> cert-manager eliminates all of that. I'll show you two things today:
> first, how it's already protecting this cluster without anyone noticing;
> second, how you use it to get a dedicated certificate for your own app."

---

## Act 1: "It's already working" (~3 min)

### Step 1 -- Deploy an app and expose it

```bash
oc new-project demo
oc create deployment web-app --image=registry.access.redhat.com/ubi9/httpd-24:latest
oc expose deployment web-app --port=8080
oc rollout status deployment/web-app --timeout=60s
oc create route edge web-app --service=web-app --insecure-policy=Redirect
```

Nothing special -- a web server with a default Route.

### Step 2 -- Show it already has a trusted certificate

```bash
ROUTE_HOST=$(oc get route web-app -o jsonpath='{.spec.host}')
ROUTER=$(oc get route web-app -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')

echo | openssl s_client -servername "$ROUTE_HOST" -connect "$ROUTER:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -ext subjectAltName
```

Output:

```
subject=CN=*.apps.cluster-z8n9x.dyn.redhatworkshops.io
issuer=C=US, O=Google Trust Services, CN=WR1
    DNS:*.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

> "Green padlock. Google-trusted. And we didn't configure any TLS.
> How is that possible?"

### Step 3 -- Reveal the Certificate resource behind the scenes

```bash
oc get certificate -n openshift-ingress
```

```
NAME                        READY   SECRET                      AGE
cert-manager-ingress-cert   True    cert-manager-ingress-cert   2d
```

```bash
oc get certificate cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='Expires:  {.status.notAfter}{"\n"}Renews at: {.status.renewalTime}{"\n"}'
```

```
Expires:  2026-12-05T13:43:09Z
Renews at: 2026-11-20T13:43:09Z
```

> "cert-manager issued a wildcard certificate from Google and installed it
> as the cluster default. It will renew automatically on November 20th.
> No human in the loop. That's layer one -- infrastructure."

**Transition**:

> "But what if your app needs its own certificate -- maybe a custom domain,
> or a compliance requirement for a dedicated cert per service?"

---

## Act 2: "Three resources, done" (~6 min)

### Step 4 -- Create a Certificate resource

> "We tell cert-manager what we need: a certificate for our app's hostname,
> signed by the cluster's ACME issuer."

```bash
ROUTE_HOST=$(oc get route web-app -o jsonpath='{.spec.host}')

cat <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-app-cert
  namespace: demo
spec:
  secretName: web-app-tls
  dnsNames:
    - $ROUTE_HOST
  issuerRef:
    name: acme-bifrost-production-ddns
    kind: ClusterIssuer
EOF
```

Watch it:

```bash
oc get certificate web-app-cert -w
```

> While waiting (~30-60 sec):
>
> "Behind the scenes, cert-manager created an ACME Order with Google's CA.
> Google challenged us to prove we own this domain by placing a DNS TXT
> record. cert-manager did that automatically. Once verified, Google signs
> the certificate and cert-manager stores it in a Secret called
> `web-app-tls`. All automatic."

Wait until `READY = True`, then Ctrl-C the watch.

### Step 5 -- Grant the router read access to the Secret

> "The OpenShift router needs permission to read our Secret. Standard RBAC,
> two commands."

```bash
oc create role secret-reader \
  --verb=get,list,watch \
  --resource=secrets \
  --resource-name=web-app-tls

oc create rolebinding router-secret-reader \
  --role=secret-reader \
  --serviceaccount=openshift-ingress:router
```

### Step 6 -- Point the Route at the Secret

> "Now the key step. We recreate the Route with one new field:
> `externalCertificate`. It tells the router: don't use the default
> wildcard -- use THIS Secret instead."

```bash
oc delete route web-app

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: demo
spec:
  host: $ROUTE_HOST
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

> "That's it. `externalCertificate.name: web-app-tls`. The router reads the
> Secret directly. When cert-manager renews the cert, the router picks up
> the new one automatically. No restart, no manual copy."

### Step 7 -- Verify: the certificate changed

```bash
sleep 5

ROUTER=$(oc get route web-app -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')

echo "--- BEFORE (shared wildcard) ---"
oc get secret cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -ext subjectAltName

echo ""
echo "--- AFTER (dedicated cert on this Route) ---"
echo | openssl s_client -servername "$ROUTE_HOST" -connect "$ROUTER:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Expected:

```
--- BEFORE (shared wildcard) ---
subject=CN=*.apps.cluster-z8n9x.dyn.redhatworkshops.io
    DNS:*.apps.cluster-z8n9x.dyn.redhatworkshops.io

--- AFTER (dedicated cert on this Route) ---
issuer=C=US, O=Google Trust Services, CN=WR1
notAfter=Dec  8 ...
    DNS:web-app-demo.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

> "The SAN changed. Before: the shared wildcard. After: a certificate
> issued specifically for this app's hostname. Same Google trust, but
> its own identity. And it renews itself."

---

## Closing

> "Three resources. That's the whole thing.
>
> **Certificate** -- you declare what you need.
> **Secret** -- cert-manager creates it, renews it, keeps it current.
> **Route** -- `externalCertificate` points at the Secret.
>
> Fully Red Hat supported on OpenShift 4.22. No extra controllers,
> no Helm charts, no community add-ons. It's built into the platform."

---

## Cleanup

```bash
oc delete project demo
```

---

## Quick reference

| What | Command |
|------|---------|
| Check certificate status | `oc get certificate -n demo` |
| See renewal schedule | `oc get certificate web-app-cert -o jsonpath='Renews: {.status.renewalTime}'` |
| Check what cert a Route serves | `echo \| openssl s_client -servername HOST -connect ROUTER:443 2>/dev/null \| openssl x509 -noout -subject` |
| View cert-manager logs | `oc logs -n cert-manager deploy/cert-manager -f` |

## If something goes wrong

| Symptom | Check |
|---------|-------|
| Certificate stuck at `Ready=False` | `oc describe certificate web-app-cert` -- look at Events |
| Route shows `ExternalCertificateValidationFailed` | RBAC missing -- verify the Role/RoleBinding exist in the namespace |
| `openssl` still shows the wildcard | Router needs a few seconds to reload; wait and retry |
