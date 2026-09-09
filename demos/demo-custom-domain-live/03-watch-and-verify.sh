#!/usr/bin/env bash
# ACT 2, Steps 7-8: Watch issuance and verify the dedicated certificate
set -euo pipefail

CUSTOM_DOMAIN="orders.apps.cluster-z8n9x.dyn.redhatworkshops.io"

echo "==========================================="
echo " Watching ACME certificate issuance"
echo "==========================================="
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

  ORDERS=$(oc get orders.acme.cert-manager.io -n custom-domain-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  CHALLENGES=$(oc get challenges.acme.cert-manager.io -n custom-domain-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  printf "\r  ACME flow in progress [certs: %s | orders: %s | challenges: %s] (%ds)" \
    "$CERT_COUNT" "$ORDERS" "$CHALLENGES" "$((i * 2))"
  sleep 2
done

echo ""
echo ""
echo "==========================================="
echo " Step 8: The Payoff"
echo "==========================================="
echo ""

echo "Certificate resource:"
oc get certificate -n custom-domain-demo
echo ""

SECRET_NAME=$(oc get certificate -n custom-domain-demo \
  -o jsonpath='{.items[0].spec.secretName}' 2>/dev/null || echo "")

if [ -n "$SECRET_NAME" ] && oc get secret "$SECRET_NAME" -n custom-domain-demo &>/dev/null; then
  echo "Dedicated certificate details:"
  oc get secret "${SECRET_NAME}" -n custom-domain-demo \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -subject -issuer -dates -ext subjectAltName | sed 's/^/  /'
  echo ""
else
  echo "(Certificate Secret not yet available)"
fi

echo "Live verification:"
echo ""
curl -sv "https://${CUSTOM_DOMAIN}" 2>&1 \
  | grep -E "subject:|issuer:|expire" | sed 's/^/  /'

echo ""
echo "==========================================="
echo " BEFORE (Act 1):  CN=*.apps.cluster-z8n9x..."
echo "                   (shared wildcard)"
echo ""
echo " AFTER  (Act 2):  CN=orders.apps.cluster-z8n9x..."
echo "                   (dedicated cert, same Google trust)"
echo "==========================================="
echo ""
echo "Browse it: https://${CUSTOM_DOMAIN}"
echo ""
echo "Cleanup: ./04-cleanup.sh"
