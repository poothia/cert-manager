#!/usr/bin/env bash
# Pre-flight: verify cluster readiness and install openshift-routes if needed
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
if [ "$READY" != "True" ]; then
  echo "   WARNING: ACME issuer is NOT ready. Demo may fail."
fi
echo ""

echo "5. openshift-routes controller:"
if oc get pods -n cert-manager --no-headers 2>/dev/null | grep -q "openshift-routes"; then
  echo "   INSTALLED:"
  oc get pods -n cert-manager --no-headers | grep openshift-routes | awk '{print "   "$1" "$3}'
else
  echo "   NOT installed. Installing now..."
  echo ""
  helm repo add jetstack https://charts.jetstack.io --force-update 2>/dev/null
  helm repo update 2>/dev/null
  helm install openshift-routes jetstack/cert-manager-openshift-routes \
    --namespace cert-manager \
    --wait --timeout 120s
  echo ""
  echo "   Installed:"
  oc get pods -n cert-manager --no-headers | grep openshift-routes | awk '{print "   "$1" "$3}'
fi
echo ""

echo "6. Apps domain:"
echo "   $(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
echo ""

echo "==========================================="
echo " Pre-flight complete. Ready for demo."
echo "==========================================="
