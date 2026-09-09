# LIVE DEMO: Secure a Custom Domain on OpenShift with cert-manager

> Tailored for cluster: `api.cluster-z8n9x.dyn.redhatworkshops.io`
> OCP 4.22.11 | cert-manager Operator v1.20.0
> ACME Issuer: `acme-bifrost-production-ddns` (Google Trust Services -- publicly trusted)

---

## What the audience sees

1. You deploy an app -- it has no TLS.
2. You create a Route with a custom hostname and two annotations.
3. Within 60 seconds, cert-manager issues a **real, publicly-trusted Google certificate**.
4. You open the URL in a browser -- **green padlock**.
5. Total: ~7 minutes.

---

## Pre-flight (do this 5 min before the demo)

### 1. Install the openshift-routes controller (one-time)

The openshift-routes controller is what connects cert-manager to OpenShift
Routes. It is NOT installed on this cluster yet. Run this once:

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

helm install openshift-routes jetstack/cert-manager-openshift-routes \
  --namespace cert-manager \
  --wait --timeout 120s
```

Verify:

```bash
oc get pods -n cert-manager | grep openshift-routes
# Should show 1/1 Running
```

### 2. Confirm the ACME issuer is ready

```bash
oc get clusterissuer acme-bifrost-production-ddns
# READY = True
```

### 3. Pick your custom hostname

Any hostname under `*.apps.cluster-z8n9x.dyn.redhatworkshops.io` will work.
The wildcard cert already covers this zone, but we're going to issue a
**dedicated** cert for our specific app to show how cert-manager works.

Suggested hostname:

```
orders.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

---

## THE DEMO

### Step 1: Deploy the app (1 min)

**What you say**: "Let's deploy a simple web application. Nothing special --
just an HTTPD server."

```bash
oc new-project custom-domain-demo

oc create deployment web-app \
  --image=registry.access.redhat.com/ubi9/httpd-24:latest \
  -n custom-domain-demo

oc expose deployment web-app --port=8080 -n custom-domain-demo

# Wait for the pod
oc rollout status deployment/web-app -n custom-domain-demo --timeout=60s
```

**Show**: `oc get pods -n custom-domain-demo` -- pod is Running.

---

### Step 2: Create a Route WITHOUT TLS first (30 sec)

**What you say**: "Let's expose it on a custom hostname first, without any TLS,
so you can see the 'before' state."

```bash
oc create route edge web-app-insecure \
  --service=web-app \
  --hostname=orders.apps.cluster-z8n9x.dyn.redhatworkshops.io \
  --insecure-policy=Allow \
  -n custom-domain-demo
```

Open in browser: `http://orders.apps.cluster-z8n9x.dyn.redhatworkshops.io`

**Show**: The browser shows the app, but HTTPS uses the cluster's default
wildcard cert, not a dedicated one for "orders". For the demo story, this
is the "before" -- we want cert-manager to issue a cert specifically for
this hostname.

Now delete this route:

```bash
oc delete route web-app-insecure -n custom-domain-demo
```

---

### Step 3: Create the Route WITH cert-manager annotations (1 min)

**What you say**: "Now let's do it the right way. Same Route, but with two
annotations that tell cert-manager to issue a dedicated TLS certificate."

```bash
cat <<'EOF' | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: custom-domain-demo
  annotations:
    cert-manager.io/issuer-name: acme-bifrost-production-ddns
    cert-manager.io/issuer-kind: ClusterIssuer
spec:
  host: orders.apps.cluster-z8n9x.dyn.redhatworkshops.io
  to:
    kind: Service
    name: web-app
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF
```

**Pause here and point at the YAML**:
> "Look -- it's a completely normal OpenShift Route. The only addition is
> these two annotations:
> - `cert-manager.io/issuer-name` tells cert-manager WHICH issuer to use
> - `cert-manager.io/issuer-kind` says it's a ClusterIssuer
>
> That's it. Two lines. cert-manager handles everything else."

---

### Step 4: Watch cert-manager work (1-2 min)

**What you say**: "Now let's watch what happens behind the scenes."

In a split terminal:

**Terminal 1** -- watch Certificates:

```bash
oc get certificate -n custom-domain-demo -w
```

**Terminal 2** -- watch ACME Orders (this is the ACME protocol in action):

```bash
oc get orders.acme.cert-manager.io -n custom-domain-demo -w
```

**While waiting, explain**:
> "Here's what's happening right now:
> 1. The openshift-routes controller saw our annotation and created a Certificate resource.
> 2. cert-manager's controller picked that up and created an ACME Order.
> 3. The ACME server (Bifrost) is creating a DNS-01 challenge -- it's adding a
>    TXT record to prove we own this domain.
> 4. Once verified, Google Trust Services issues and signs the certificate.
> 5. cert-manager stores it in a Secret, and the openshift-routes controller
>    patches it onto our Route.
>
> All of this -- automated, auditable, renewable."

Wait until the Certificate shows `READY = True` (typically 30-90 seconds on this cluster).

---

### Step 5: Verify -- the money shot (2 min)

#### 5a. Inspect the certificate

```bash
SECRET_NAME=$(oc get certificate -n custom-domain-demo \
  -o jsonpath='{.items[0].spec.secretName}')

oc get secret "${SECRET_NAME}" -n custom-domain-demo \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

**Expected output**:
```
subject=CN=orders.apps.cluster-z8n9x.dyn.redhatworkshops.io
issuer=C=US, O=Google Trust Services, CN=WR1
notBefore=...
notAfter=... (90 days from now)
X509v3 Subject Alternative Name:
    DNS:orders.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

**Point out**: "The issuer is **Google Trust Services** -- this is a real,
publicly-trusted certificate. Not self-signed, not internal. Google signed it."

#### 5b. Open in browser

```
https://orders.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

**Show**: Click the padlock icon in the browser. Show the certificate details:
- Issued to: `orders.apps.cluster-z8n9x.dyn.redhatworkshops.io`
- Issued by: Google Trust Services
- Valid for 90 days

**What you say**: "Green padlock. A real, browser-trusted certificate, issued
automatically, in under a minute. And it will renew itself before it expires.
Zero manual steps."

#### 5c. curl verification

```bash
curl -sv https://orders.apps.cluster-z8n9x.dyn.redhatworkshops.io 2>&1 \
  | grep -E "subject:|issuer:|expire date:|HTTP/"
```

---

### Step 6: Show the renewal story (30 sec, no waiting)

```bash
oc get certificate -n custom-domain-demo -o wide
```

**Point out the RENEWAL column**:
> "See this renewal time? cert-manager will automatically request a new
> certificate before expiry. No calendar reminders, no tickets, no outages.
> If you set `renewBefore: 360h` (15 days), it renews 15 days before expiry.
> The default on this cluster is 2/3 of the cert lifetime."

---

### Cleanup

```bash
oc delete project custom-domain-demo
```

---

## Troubleshooting cheat sheet

| Symptom | Quick fix |
|---------|-----------|
| Certificate stuck at `False` | `oc describe certificate -n custom-domain-demo` -- check Events |
| Order stuck at `pending` | `oc get challenges -n custom-domain-demo` -- DNS propagation |
| Route TLS empty after 2 min | `oc get pods -n cert-manager \| grep routes` -- is the controller running? |
| "connection refused" errors | The fallback issuer has intermittent DNS issues -- use `acme-bifrost-production-ddns` (primary) only |

---

## Summary for the audience

| Before (manual) | After (cert-manager) |
|-----------------|---------------------|
| File a ticket to security team | Add 2 annotations |
| Wait days for the cert | 60 seconds |
| Manually configure the Route | Automatic |
| Set calendar reminder to renew | Automatic renewal |
| Risk of outage on expiry | Zero risk |
