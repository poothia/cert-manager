#!/usr/bin/env bash
# ACT 2, Step 8: Verify the Route is serving the dedicated cert
set -euo pipefail

ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')
ROUTER_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')

echo "==========================================="
echo " Step 8: Verification"
echo "==========================================="
echo ""
echo "Waiting for the router to load the new certificate..."
sleep 5
echo ""

echo "=== BEFORE: Shared wildcard (what every route gets by default) ==="
oc get secret cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -ext subjectAltName | sed 's/^/  /'

echo ""
echo "=== AFTER: Dedicated cert (what THIS Route now serves) ==="
echo | openssl s_client -servername "${ROUTE_HOST}" \
  -connect "${ROUTER_HOST}:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName | sed 's/^/  /'

echo ""
echo "==========================================="
echo " The SAN changed!"
echo "   Before: *.apps.cluster-z8n9x...  (shared wildcard)"
echo "   After:  ${ROUTE_HOST}"
echo "           (dedicated cert, Google Trust Services)"
echo ""
echo " Three resources. Fully Red Hat supported."
echo "   1. Certificate (cert-manager issues it)"
echo "   2. Secret      (auto-created, stores cert+key)"
echo "   3. Route        (externalCertificate references the Secret)"
echo "==========================================="
echo ""

echo "Renewal schedule:"
oc get certificate web-app-cert -n custom-domain-demo \
  -o jsonpath='  Expires:  {.status.notAfter}{"\n"}  Renews at: {.status.renewalTime}{"\n"}'
echo ""
echo ""
echo "Cleanup: ./04-cleanup.sh"
