# Demo: Secure a Custom Domain on OpenShift with cert-manager

A single end-to-end demo that tells this story:

> "I deploy an app, I point my own domain at it, and cert-manager
> automatically gives it a trusted TLS certificate -- zero manual steps."

Two paths are provided so you can choose on the day based on what's available:

- **Path A** -- Internal CA (works in any lab, no external dependencies)
- **Path B** -- Let's Encrypt with a real domain (green padlock in browser)

Both paths share the same Steps 1-3. They diverge only at Step 4 (which issuer).

---

## Prerequisites

| Requirement | Path A (Internal CA) | Path B (Let's Encrypt) |
|-------------|---------------------|----------------------|
| OCP 4.20+ cluster with cluster-admin | Yes | Yes |
| cert-manager operator installed | Yes | Yes |
| openshift-routes controller installed | Yes | Yes |
| A real domain you control | No | Yes |
| DNS API token (Cloudflare / Route53) | No | Yes |
| `oc`, `openssl` on your laptop | Yes | Yes |

---

## The Story (what you tell the audience)

> "Imagine you're a platform engineer. A dev team just deployed their app
> on OpenShift and they need a custom domain -- `orders.acme-corp.com`.
>
> In the old world, you'd file a ticket to the security team, wait days
> for a cert, manually configure the Route, and set a calendar reminder
> to renew it in 90 days.
>
> With cert-manager, you add two annotations to the Route and walk away.
> cert-manager issues the cert, attaches it to the Route, and renews it
> forever. Let me show you."

---

## Step 1: Deploy the application (both paths)

```bash
# Create a dedicated namespace
oc new-project custom-domain-demo

# Deploy a simple HTTPD app
oc create deployment web-app \
  --image=registry.access.redhat.com/ubi9/httpd-24:latest \
  -n custom-domain-demo

# Expose it as a Service on port 8080
oc expose deployment web-app --port=8080 -n custom-domain-demo

# Wait for the pod to be Running
oc get pods -n custom-domain-demo -w
```

**What you say**: "Here's our app -- a simple web server running in OpenShift.
Right now it has no Route, no domain, no TLS. Let's fix that."

---

## Step 2: Create a Route with your custom domain (both paths)

### Path A -- Internal CA (fake custom domain)

Since we don't have a real domain, we'll use a hostname and add it to
`/etc/hosts` for the demo. Pick a memorable name:

```bash
# Get the cluster's router IP (the ingress load balancer)
ROUTER_IP=$(oc get svc -n openshift-ingress router-default \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null \
  || oc get svc -n openshift-ingress router-default \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null \
  || echo "<use-your-router-ip>")

echo "Router IP/hostname: ${ROUTER_IP}"

# Add to /etc/hosts (or tell attendees to do so)
# sudo echo "${ROUTER_IP}  orders.acme-corp.internal" >> /etc/hosts
```

The custom domain for Path A: `orders.acme-corp.internal`

### Path B -- Real domain (Let's Encrypt)

Point your real domain at the cluster's router:
- Create a DNS A record: `orders.acme-corp.com` → `<ROUTER_IP>`
- Or a CNAME to the router's hostname

The custom domain for Path B: `orders.acme-corp.com` (replace with your actual domain)

```bash
# Set your domain as a variable (used in the next steps)
# Path A:
CUSTOM_DOMAIN="orders.acme-corp.internal"
# Path B:
# CUSTOM_DOMAIN="orders.acme-corp.com"
```

---

## Step 3: Confirm the issuer is ready (both paths)

### Path A -- Internal CA issuer

Make sure the self-signed CA chain from earlier labs exists:

```bash
oc get clusterissuer ca-issuer
# STATUS: True

# If it doesn't exist, create it quickly:
# oc apply -f ../demo-01-install/  (if operator not installed)
# oc apply -f ../../labs/lab-01-self-signed/
```

### Path B -- Let's Encrypt issuer

```bash
oc get clusterissuer letsencrypt-staging
# or letsencrypt-prod if you're using production
# STATUS: True

# If it doesn't exist:
# oc apply -f ../demo-02-acme/00-secret-dns-api-token.yaml
# oc apply -f ../demo-02-acme/01-clusterissuer-letsencrypt-staging.yaml
```

---

## Step 4: Create the Route with cert-manager annotations

This is the magic step. We create a Route with a custom domain AND cert-manager
annotations. The openshift-routes controller will see the annotations and
automatically request + attach a TLS certificate.

### Path A -- Internal CA

```bash
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: custom-domain-demo
  annotations:
    # These two annotations are all cert-manager needs
    cert-manager.io/issuer-name: ca-issuer
    cert-manager.io/issuer-kind: ClusterIssuer
spec:
  host: ${CUSTOM_DOMAIN}
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

### Path B -- Let's Encrypt

```bash
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: custom-domain-demo
  annotations:
    cert-manager.io/issuer-name: letsencrypt-prod
    cert-manager.io/issuer-kind: ClusterIssuer
spec:
  host: ${CUSTOM_DOMAIN}
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

**What you say**: "Look at the YAML. It's a completely normal Route with a
custom hostname. The only addition is two annotations -- `issuer-name` and
`issuer-kind`. That's it. cert-manager handles everything else."

---

## Step 5: Watch cert-manager do its thing

Open a split terminal (or use tmux) and watch in real time:

**Terminal 1** -- Watch the Certificate resource appear:

```bash
oc get certificate -n custom-domain-demo -w
```

**Terminal 2** -- Watch the Route TLS get populated:

```bash
# Poll every 2 seconds until TLS appears
while true; do
  TLS=$(oc get route web-app -n custom-domain-demo \
    -o jsonpath='{.spec.tls.certificate}' 2>/dev/null)
  if [ -n "$TLS" ]; then
    echo "TLS certificate attached to Route!"
    break
  fi
  echo "Waiting for cert-manager to attach the certificate..."
  sleep 2
done
```

**What you say** (while waiting):
"Behind the scenes, here's what's happening:
1. The openshift-routes controller saw our annotation and created a Certificate resource.
2. cert-manager's controller picked up that Certificate and asked the CA issuer to sign it.
3. The signed cert + key were stored in a Kubernetes Secret.
4. The openshift-routes controller read that Secret and patched the Route's TLS section.
All of this happened in seconds, with zero manual steps."

For Path B (Let's Encrypt), this takes 30-90 seconds due to the ACME challenge.
For Path A (internal CA), this takes 5-15 seconds.

---

## Step 6: Verify -- the money shot

### Check the certificate details

```bash
# See the Certificate resource
oc get certificate -n custom-domain-demo
# NAME                   READY   SECRET                 AGE
# web-app-xxxxx          True    web-app-xxxxx-tls      30s

# Inspect what cert-manager issued
SECRET_NAME=$(oc get certificate -n custom-domain-demo -o jsonpath='{.items[0].spec.secretName}')
oc get secret "${SECRET_NAME}" -n custom-domain-demo \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout \
  | grep -E "Issuer:|Subject:|Not After|DNS:"
```

**Expected output (Path A)**:
```
Issuer: CN = Workshop Root CA
Subject:
Not After : Dec  8 10:30:00 2026 GMT
DNS:orders.acme-corp.internal
```

**Expected output (Path B)**:
```
Issuer: C = US, O = Let's Encrypt, CN = R11
Subject:
Not After : Dec  8 10:30:00 2026 GMT
DNS:orders.acme-corp.com
```

### Hit the app in the browser / curl

**Path A** (add `--cacert` since the CA is internal):

```bash
# Extract the CA cert
oc get secret root-ca-secret -n cert-manager \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/workshop-ca.crt

# Test
curl --cacert /tmp/workshop-ca.crt "https://${CUSTOM_DOMAIN}"
```

**Path B** (no `--cacert` needed -- Let's Encrypt is publicly trusted):

```bash
curl "https://${CUSTOM_DOMAIN}"
# Or simply open in the browser -- green padlock!
```

**What you say**: "That's it. Our app is now serving on a custom domain with
a valid TLS certificate. cert-manager issued it, attached it to the Route,
and will automatically renew it before it expires. No tickets, no calendar
reminders, no 3 AM pages."

---

## Step 7: Show auto-renewal (optional, if time permits)

```bash
# Check when cert-manager will renew
oc get certificate -n custom-domain-demo -o wide
# The RENEWAL column shows when the next renewal will happen

# For a faster demo, you could have pre-created a cert with:
#   cert-manager.io/duration: "1h"
#   cert-manager.io/renew-before: "50m"
# Then it renews ~10 min after creation -- you can watch it live.
```

---

## Cleanup

```bash
oc delete project custom-domain-demo
```

---

## Troubleshooting during the demo

| Symptom | Fix |
|---------|-----|
| Certificate stuck at `Ready=False` | `oc describe certificate -n custom-domain-demo` -- check the issuer is ready |
| Route TLS not populated | Verify openshift-routes controller pod is running: `oc get pods -n cert-manager \| grep routes` |
| ACME challenge failing (Path B) | DNS not propagated yet. Wait 60s and check: `dig TXT _acme-challenge.orders.acme-corp.com` |
| curl: "certificate signed by unknown authority" (Path A) | Expected! Use `--cacert` or `-k`. Explain to audience that internal CA needs explicit trust. |
| Pod not starting | Check image pull: `oc describe pod -n custom-domain-demo` |

---

## Timing

| Step | Duration | Notes |
|------|----------|-------|
| Step 1: Deploy app | 1 min | Quick, just 3 commands |
| Step 2: Set up domain | 1 min | Path A: instant. Path B: DNS may take a moment. |
| Step 3: Check issuer | 30 sec | Should already be ready from earlier |
| Step 4: Create annotated Route | 1 min | The key moment -- pause and explain the annotations |
| Step 5: Watch cert-manager | 1-2 min | Path A: ~15 sec. Path B: ~60 sec. Fill with explanation. |
| Step 6: Verify | 2 min | The payoff -- show the cert, hit the URL |
| **Total** | **~7 min** | Fits comfortably in a 10-15 min demo slot |
