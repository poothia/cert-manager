#!/usr/bin/env bash
# Step 5-6: Watch cert-manager issue the cert and verify
set -euo pipefail

echo "=== Watching for certificate issuance ==="
echo ""

echo "Certificates in the namespace:"
oc get certificate -n custom-domain-demo 2>/dev/null || echo "(none yet -- waiting)"
echo ""

echo "Waiting for the Route TLS to be populated..."
for i in $(seq 1 60); do
  TLS_CERT=$(oc get route web-app -n custom-domain-demo \
    -o jsonpath='{.spec.tls.certificate}' 2>/dev/null || true)
  if [ -n "$TLS_CERT" ]; then
    echo ""
    echo "TLS certificate attached to Route! (took ~$((i * 2)) seconds)"
    break
  fi
  printf "\r  Polling... (%d/60)" "$i"
  sleep 2
done

echo ""
echo "=== Certificate Details ==="
echo ""

oc get certificate -n custom-domain-demo
echo ""

SECRET_NAME=$(oc get certificate -n custom-domain-demo \
  -o jsonpath='{.items[0].spec.secretName}' 2>/dev/null || echo "")

if [ -n "$SECRET_NAME" ]; then
  echo "Secret: ${SECRET_NAME}"
  echo ""
  echo "Certificate info:"
  oc get secret "${SECRET_NAME}" -n custom-domain-demo \
    -o jsonpath='{.data.tls\.crt}' | base64 -d \
    | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null
else
  echo "No certificate Secret found yet."
fi

echo ""
echo "=== Route ==="
ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')
echo "URL: https://${ROUTE_HOST}"
echo ""

echo "Quick curl test (with -k to skip CA validation):"
curl -sk -o /dev/null -w "  HTTP Status: %{http_code}\n  TLS Version: %{ssl_version}\n" \
  "https://${ROUTE_HOST}" || echo "  (curl failed -- check DNS / /etc/hosts)"
