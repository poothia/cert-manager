#!/usr/bin/env bash
# Demo 3 (Advanced): Patch the default IngressController to use
# the cert-manager-managed wildcard certificate.
#
# After running this, ALL routes that don't specify their own certificate
# will use the cert-manager-issued wildcard cert.
#
# WARNING: This changes the default TLS certificate for the entire cluster.
#          In a workshop, only demonstrate this on a lab/demo cluster.

set -euo pipefail

echo "============================================"
echo " Patching Default IngressController"
echo "============================================"
echo ""

# First, verify the certificate is ready
echo "Checking if the wildcard certificate is ready..."
READY=$(oc get certificate default-ingress-cert -n openshift-ingress -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

if [ "$READY" != "True" ]; then
  echo "ERROR: Certificate 'default-ingress-cert' is not ready yet."
  echo "Status:"
  oc get certificate default-ingress-cert -n openshift-ingress 2>/dev/null || echo "  Certificate not found"
  echo ""
  echo "Apply the certificate first:"
  echo "  oc apply -f 00-certificate-wildcard.yaml"
  exit 1
fi

echo "Certificate is ready. Patching the IngressController..."
echo ""

oc patch ingresscontroller default -n openshift-ingress-operator \
  --type merge \
  -p '{"spec":{"defaultCertificate":{"name":"router-certs-custom"}}}'

echo ""
echo "IngressController patched. The router pods will restart with the new certificate."
echo ""
echo "Watch the rollout:"
echo "  oc get pods -n openshift-ingress -w"
echo ""
echo "Verify the new certificate is served:"
APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.example.com")
echo "  curl -kv https://console-openshift-console.${APPS_DOMAIN} 2>&1 | grep -A2 'Server certificate'"
echo ""
echo "To revert to the default self-signed certificate:"
echo "  oc patch ingresscontroller default -n openshift-ingress-operator --type merge -p '{\"spec\":{\"defaultCertificate\":null}}'"
