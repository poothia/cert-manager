#!/usr/bin/env bash
# Demo 4 - Step 1: Enable trust-manager on the cert-manager operator
#
# trust-manager is a Technology Preview feature that distributes CA trust
# bundles to namespaces across the cluster automatically.

set -euo pipefail

echo "============================================"
echo " Demo 4: Enabling trust-manager"
echo "============================================"
echo ""

echo "Patching the cert-manager operator subscription..."
oc -n cert-manager-operator patch subscription openshift-cert-manager-operator \
  --type merge \
  -p '{"spec":{"config":{"env":[{"name":"UNSUPPORTED_ADDON_FEATURES","value":"TrustManager=true"}]}}}'
echo ""

echo "Waiting for trust-manager pod to start..."
for i in $(seq 1 30); do
  if oc get pods -n cert-manager 2>/dev/null | grep -q "trust-manager.*Running"; then
    echo ""
    echo "trust-manager is running:"
    oc get pods -n cert-manager | grep trust-manager
    echo ""
    echo "trust-manager CRDs installed:"
    oc get crd bundles.trust.cert-manager.io 2>/dev/null && echo "  bundles.trust.cert-manager.io -- OK"
    exit 0
  fi
  printf "  Waiting... (%d/30)\r" "$i"
  sleep 5
done

echo ""
echo "WARNING: trust-manager did not reach Running state within 150 seconds."
echo "Debug: oc get pods -n cert-manager"
