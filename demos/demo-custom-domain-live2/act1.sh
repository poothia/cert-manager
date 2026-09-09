#!/usr/bin/env bash
# Act 1: Deploy an app, show it already has a Google-trusted cert via the wildcard.
set -euo pipefail

echo "=== Act 1: It's already working ==="
echo ""

# Step 1 -- Deploy and expose
echo "Step 1: Deploying app..."
oc new-project demo 2>/dev/null || oc project demo
oc create deployment web-app --image=registry.access.redhat.com/ubi9/httpd-24:latest 2>/dev/null || true
oc expose deployment web-app --port=8080 2>/dev/null || true
oc rollout status deployment/web-app --timeout=60s
oc create route edge web-app --service=web-app --insecure-policy=Redirect 2>/dev/null || true
echo ""

ROUTE_HOST=$(oc get route web-app -o jsonpath='{.spec.host}')
ROUTER=$(oc get route web-app -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')

# Step 2 -- Show the cert
echo "Step 2: Certificate being served on https://${ROUTE_HOST}"
echo ""
echo | openssl s_client -servername "$ROUTE_HOST" -connect "$ROUTER:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -ext subjectAltName | sed 's/^/  /'
echo ""

# Step 3 -- Reveal the wildcard Certificate resource
echo "Step 3: The Certificate resource behind this:"
oc get certificate -n openshift-ingress --no-headers | sed 's/^/  /'
echo ""
oc get certificate cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='  Expires:  {.status.notAfter}{"\n"}  Renews at: {.status.renewalTime}{"\n"}'
echo ""
echo ""
echo "=== Act 1 complete. Run ./act2.sh for Act 2. ==="
