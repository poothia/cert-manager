#!/usr/bin/env bash
# Steps 4-5: Watch cert-manager issue the cert and verify
set -euo pipefail

CUSTOM_DOMAIN="orders.apps.cluster-z8n9x.dyn.redhatworkshops.io"

echo "=== Watching for certificate issuance ==="
echo ""

echo "Polling until the certificate is ready..."
echo "(ACME issuance typically takes 30-90 seconds on this cluster)"
echo ""

for i in $(seq 1 90); do
  CERT_COUNT=$(oc get certificate -n custom-domain-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CERT_COUNT" -gt 0 ]; then
    CERT_READY=$(oc get certificate -n custom-domain-demo \
      -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$CERT_READY" = "True" ]; then
      echo ""
      echo "Certificate is READY!"
      break
    fi
  fi

  # Show what's happening
  ORDERS=$(oc get orders.acme.cert-manager.io -n custom-domain-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  CHALLENGES=$(oc get challenges.acme.cert-manager.io -n custom-domain-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  printf "\r  Waiting... [certs: %s | orders: %s | challenges: %s] (%ds)" \
    "$CERT_COUNT" "$ORDERS" "$CHALLENGES" "$((i * 2))"
  sleep 2
done

echo ""
echo ""
echo "=== Certificate Status ==="
oc get certificate -n custom-domain-demo
echo ""

echo "=== Certificate Details ==="
SECRET_NAME=$(oc get certificate -n custom-domain-demo \
  -o jsonpath='{.items[0].spec.secretName}' 2>/dev/null || echo "")

if [ -n "$SECRET_NAME" ] && oc get secret "$SECRET_NAME" -n custom-domain-demo &>/dev/null; then
  oc get secret "${SECRET_NAME}" -n custom-domain-demo \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
else
  echo "(Certificate not yet available in Secret)"
fi

echo ""
echo "=== Route TLS Status ==="
TLS_CERT=$(oc get route web-app -n custom-domain-demo \
  -o jsonpath='{.spec.tls.certificate}' 2>/dev/null || echo "")
if [ -n "$TLS_CERT" ]; then
  echo "TLS certificate is attached to the Route."
else
  echo "TLS certificate NOT yet attached to the Route."
  echo "The openshift-routes controller may still be reconciling."
fi

echo ""
echo "=== Verify in Browser ==="
echo ""
echo "  https://${CUSTOM_DOMAIN}"
echo ""

echo "=== curl Verification ==="
curl -sv "https://${CUSTOM_DOMAIN}" 2>&1 \
  | grep -E "subject:|issuer:|expire date:|HTTP/" \
  | sed 's/^/  /' || echo "  (curl failed -- certificate may still be propagating)"

echo ""
echo "=== Renewal Info ==="
oc get certificate -n custom-domain-demo -o wide 2>/dev/null || true
