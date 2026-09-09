#!/usr/bin/env bash
# Pre-flight: verify cluster readiness (no installs needed on OCP 4.22)
set -euo pipefail

echo "==========================================="
echo " Pre-flight: Cluster Verification"
echo "==========================================="
echo ""

echo "1. Cluster access:"
echo "   User:    $(oc whoami)"
echo "   Server:  $(oc whoami --show-server)"
echo "   Version: $(oc get clusterversion version -o jsonpath='{.status.desired.version}')"
echo ""

echo "2. cert-manager operator:"
oc get csv -n cert-manager-operator --no-headers 2>/dev/null | awk '{print "   "$1" "$6}'
echo ""

echo "3. cert-manager pods:"
oc get pods -n cert-manager --no-headers | awk '{print "   "$1" "$3}'
echo ""

echo "4. ACME issuer status:"
READY=$(oc get clusterissuer acme-bifrost-production-ddns -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
echo "   acme-bifrost-production-ddns: Ready=${READY}"
echo ""

echo "5. externalCertificate support (OCP 4.22 -- GA, always enabled):"
if oc explain route.spec.tls.externalCertificate &>/dev/null; then
  echo "   OK: route.spec.tls.externalCertificate field is available"
else
  echo "   ERROR: externalCertificate field not found -- requires OCP 4.22+"
fi
echo ""

echo "6. Apps domain:"
echo "   $(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
echo ""

echo "==========================================="
echo " Pre-flight complete. Ready for demo."
echo " No additional installs needed."
echo "==========================================="
