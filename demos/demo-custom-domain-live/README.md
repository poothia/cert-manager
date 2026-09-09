# LIVE DEMO: Two Layers of TLS Automation with cert-manager

> Tailored for cluster: `cluster-z8n9x.dyn.redhatworkshops.io`
> OCP 4.22.11 | cert-manager Operator v1.20.0
> ACME Issuer: `acme-bifrost-production-ddns` (Google Trust Services)

---

## The Story

This demo has two acts:

**Act 1 -- "The invisible guardian"**
Show that cert-manager is ALREADY securing the entire cluster -- every Route
gets a Google-trusted certificate automatically via a wildcard cert. Most
people on this cluster don't even know cert-manager exists.

**Act 2 -- "The custom domain"**
A customer comes to you with their own domain (`orders.acme-corp.com`). The
wildcard doesn't cover it. You use cert-manager annotations on a Route to
issue a dedicated certificate for that specific hostname.

---

## Pre-flight (do this 5 min before the demo)

### Install the openshift-routes controller (one-time, needed for Act 2)

```bash
./00-preflight.sh
```

This checks the cluster and installs the openshift-routes controller if missing.

---

## ACT 1: The Invisible Guardian (~5 min)

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

Create a basic Route (no annotations, nothing special):

```bash
oc create route edge web-app \
  --service=web-app \
  --insecure-policy=Redirect \
  -n custom-domain-demo
```

### Step 2: Show it's already secured

```bash
ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')
echo "Route: https://${ROUTE_HOST}"
```

Open in a browser or curl:

```bash
curl -sv "https://${ROUTE_HOST}" 2>&1 | grep -E "subject:|issuer:|expire|HTTP/"
```

**Expected output**:
```
subject: CN=*.apps.cluster-z8n9x.dyn.redhatworkshops.io
issuer: C=US; O=Google Trust Services; CN=WR1
expire date: Dec  5 13:43:09 2026 GMT
HTTP/2 200
```

**What you say**: "Look at that -- green padlock, Google-trusted certificate,
and we didn't configure ANY TLS. How?"

### Step 3: Reveal the secret -- cert-manager manages the wildcard

```bash
# Show the wildcard certificate in the openshift-ingress namespace
oc get certificate -n openshift-ingress
```

```
NAME                        READY   SECRET                      AGE
cert-manager-ingress-cert   True    cert-manager-ingress-cert   2d
```

```bash
# Show what it covers
oc get secret cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

```
subject=CN=*.apps.cluster-z8n9x.dyn.redhatworkshops.io
issuer=C=US, O=Google Trust Services, CN=WR1
notBefore=Sep  6 13:43:10 2026 GMT
notAfter=Dec  5 13:43:09 2026 GMT
X509v3 Subject Alternative Name:
    DNS:*.apps.cluster-z8n9x.dyn.redhatworkshops.io
```

**What you say**:
> "THIS is cert-manager's first job. It issued a wildcard certificate from
> Google Trust Services that covers every `*.apps` hostname on this cluster.
> It's installed as the default IngressController certificate. Every Route
> you create automatically gets this cert. And cert-manager will renew it
> automatically before it expires on December 5th."

```bash
# Show the renewal schedule
oc get certificate cert-manager-ingress-cert -n openshift-ingress -o wide
```

> "See that RENEWAL column? cert-manager will request a fresh cert 15 days
> before expiry. No tickets, no calendar reminders, no 3 AM pages."

### Step 4: Show the issuer behind it

```bash
oc get clusterissuer acme-bifrost-production-ddns
```

> "The ClusterIssuer tells cert-manager HOW to get certs. This one uses the
> ACME protocol with DNS-01 challenges -- the same protocol Let's Encrypt
> uses. The certificate authority is Google Trust Services."

**Transition**: "So that's layer one -- the infrastructure layer. cert-manager
secures the entire cluster invisibly. But what happens when a customer has
their OWN domain?"

---

## ACT 2: The Custom Domain (~7 min)

**What you say**: "A customer comes to you and says: 'I need my app on
`orders.acme-corp.com`. That's MY domain -- not your cluster domain.'
The wildcard cert doesn't cover that. Let's use cert-manager to fix this."

### Step 5: Show the problem

First, let's create a Route with a custom hostname to show it has no
dedicated cert.

For this demo, we'll use a hostname under the cluster's zone so the ACME
issuer can issue a real cert for it. In production, this would be the
customer's actual domain.

```bash
# Delete the old route
oc delete route web-app -n custom-domain-demo

# Create a new Route with a custom subdomain
cat <<'EOF' | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app-custom
  namespace: custom-domain-demo
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

```bash
curl -sv https://orders.apps.cluster-z8n9x.dyn.redhatworkshops.io 2>&1 \
  | grep "subject:"
```

> "Right now it's using the shared wildcard: `CN=*.apps.cluster-z8n9x...`.
> That works, but the customer wants a certificate issued specifically for
> THEIR domain. Maybe they need it for compliance, maybe their security
> team requires a dedicated cert per service, maybe the domain is
> completely external and the wildcard doesn't cover it at all."

### Step 6: Add cert-manager annotations -- the two-line fix

```bash
oc delete route web-app-custom -n custom-domain-demo

cat <<'EOF' | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app-custom
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

**Pause on the YAML**:
> "Spot the difference. Two annotations:
> - `cert-manager.io/issuer-name` -- which CA to use
> - `cert-manager.io/issuer-kind` -- it's a cluster-wide issuer
>
> The openshift-routes controller sees these, tells cert-manager to issue a
> DEDICATED certificate for `orders.apps.cluster-z8n9x...`, and patches it
> onto this Route. Let's watch."

### Step 7: Watch the ACME flow in real time

Split terminal:

**Terminal 1** -- Certificates:
```bash
oc get certificate -n custom-domain-demo -w
```

**Terminal 2** -- ACME Orders and Challenges:
```bash
watch -n2 'echo "=== Orders ===" && oc get orders.acme.cert-manager.io -n custom-domain-demo 2>/dev/null && echo "" && echo "=== Challenges ===" && oc get challenges.acme.cert-manager.io -n custom-domain-demo 2>/dev/null'
```

**While waiting (~30-90 sec), explain the ACME flow**:
> "What's happening right now:
> 1. openshift-routes controller created a Certificate resource
> 2. cert-manager created an ACME Order -- that's a request to the CA
> 3. The CA said 'prove you own this domain' via a DNS-01 Challenge
> 4. cert-manager added a TXT record to DNS automatically
> 5. Google verified the TXT record and is signing the certificate
> 6. Once signed, cert-manager stores it in a Secret
> 7. The openshift-routes controller reads the Secret and patches the Route
>
> All automated. All auditable. All renewable."

### Step 8: The payoff -- dedicated certificate

Once the Certificate shows `READY = True`:

```bash
curl -sv https://orders.apps.cluster-z8n9x.dyn.redhatworkshops.io 2>&1 \
  | grep -E "subject:|issuer:|expire"
```

**Expected output** -- notice the subject changed:
```
subject: CN=orders.apps.cluster-z8n9x.dyn.redhatworkshops.io
issuer: C=US; O=Google Trust Services; CN=WR1
expire date: Dec  9 ... 2026 GMT
```

**What you say**:
> "Look at the subject line. Before, it was `CN=*.apps.cluster-z8n9x...` --
> the shared wildcard. Now it's `CN=orders.apps.cluster-z8n9x...` -- a
> DEDICATED certificate, issued specifically for this hostname.
>
> Still Google-trusted. Still a green padlock. But now this service has its
> own identity. And cert-manager will renew it automatically."

Also inspect the Certificate resource:

```bash
oc get certificate -n custom-domain-demo

SECRET_NAME=$(oc get certificate -n custom-domain-demo \
  -o jsonpath='{.items[0].spec.secretName}')
oc get secret "${SECRET_NAME}" -n custom-domain-demo \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

---

## RECAP SLIDE (what you say to close)

> "So you've seen two layers of cert-manager in action:
>
> **Layer 1 -- Infrastructure**: cert-manager issues and renews the cluster's
> wildcard certificate. Every Route gets TLS by default. Nobody has to think
> about it.
>
> **Layer 2 -- Application**: When an app needs its own domain or its own
> certificate, two annotations on the Route trigger cert-manager to issue a
> dedicated, publicly-trusted cert. Fully automated, fully renewable.
>
> The result? Your security team is happy (every service has TLS), your ops
> team is happy (zero manual cert management), and your developers are happy
> (they just add two annotations). That's cert-manager on OpenShift."

---

## Cleanup

```bash
oc delete project custom-domain-demo
```

---

## Timing

| Step | Duration |
|------|----------|
| Act 1: Steps 1-4 (show wildcard) | ~4 min |
| Transition | 30 sec |
| Act 2: Steps 5-8 (custom domain) | ~5 min |
| Recap | 1 min |
| **Total** | **~10 min** |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Act 2 cert stuck at `False` | `oc describe certificate -n custom-domain-demo` -- check Events for ACME errors |
| Order stuck at `pending` | `oc get challenges -n custom-domain-demo` -- DNS propagation delay, wait 60s more |
| Route TLS not updating after cert is Ready | openshift-routes pod may need a moment; check `oc logs -n cert-manager deploy/cert-manager-openshift-routes` |
| curl still shows wildcard after cert issued | Browser/curl may cache; try `curl --no-sessionid` or incognito window |
