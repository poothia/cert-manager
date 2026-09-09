#!/usr/bin/env bash
# Lab 4 - Step 1: Enable trust-manager on the cert-manager operator subscription
#
# trust-manager is a Technology Preview add-on that distributes CA trust bundles
# to namespaces across the cluster.
#
# As of cert-manager operator v1.19+, enabling TrustManager no longer requires
# the cluster FeatureSet to be set to TechPreviewNoUpgrade.

set -euo pipefail

echo "Patching the cert-manager operator subscription to enable trust-manager..."

oc -n cert-manager-operator patch subscription openshift-cert-manager-operator \
  --type merge \
  -p '{"spec":{"config":{"env":[{"name":"UNSUPPORTED_ADDON_FEATURES","value":"TrustManager=true"}]}}}'

echo ""
echo "Waiting for trust-manager pod to start..."
echo "(This may take 1-2 minutes as the operator reconciles)"
echo ""

# Wait up to 120 seconds for the trust-manager pod
for i in $(seq 1 24); do
  if oc get pods -n cert-manager 2>/dev/null | grep -q "trust-manager.*Running"; then
    echo "trust-manager pod is running:"
    oc get pods -n cert-manager | grep trust-manager
    exit 0
  fi
  echo "  Waiting... (${i}/24)"
  sleep 5
done

echo "WARNING: trust-manager pod did not reach Running state within 120 seconds."
echo "Check: oc get pods -n cert-manager"
