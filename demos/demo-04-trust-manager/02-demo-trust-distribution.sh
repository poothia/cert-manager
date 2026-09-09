#!/usr/bin/env bash
# Demo 4 - Step 3: Demonstrate trust bundle distribution
#
# This script creates namespaces, labels them, and shows the automatic
# distribution of CA bundles by trust-manager.

set -euo pipefail

echo "============================================"
echo " Demo 4: trust-manager in Action"
echo "============================================"
echo ""

echo "Step 1: Create the Bundle resource..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
oc apply -f "${SCRIPT_DIR}/01-bundle.yaml"
echo ""

echo "Step 2: Create test namespaces and label them..."
for NS in trust-demo-app1 trust-demo-app2 trust-demo-app3; do
  oc create namespace "${NS}" 2>/dev/null || true
  oc label namespace "${NS}" trust.cert-manager.io/inject=true --overwrite
  echo "  Labeled namespace: ${NS}"
done
echo ""

echo "Step 3: Wait a few seconds for trust-manager to reconcile..."
sleep 10
echo ""

echo "Step 4: Check for distributed ConfigMaps..."
echo ""
for NS in trust-demo-app1 trust-demo-app2 trust-demo-app3; do
  if oc get configmap workshop-ca-bundle -n "${NS}" &>/dev/null; then
    echo "  [OK] ConfigMap 'workshop-ca-bundle' found in namespace '${NS}'"
    # Show first line of the cert to prove it's real
    FIRST_LINE=$(oc get configmap workshop-ca-bundle -n "${NS}" \
      -o jsonpath='{.data.ca-bundle\.crt}' | head -1)
    echo "       Content starts with: ${FIRST_LINE}"
  else
    echo "  [MISSING] ConfigMap not yet in namespace '${NS}'"
  fi
done
echo ""

echo "Step 5: Show how a pod would mount this bundle..."
cat <<'EOF'
  # In a Deployment spec:
  volumes:
    - name: ca-bundle
      configMap:
        name: workshop-ca-bundle
  containers:
    - name: my-app
      volumeMounts:
        - name: ca-bundle
          mountPath: /etc/pki/tls/certs/workshop-ca.crt
          subPath: ca-bundle.crt
          readOnly: true
      env:
        - name: SSL_CERT_FILE
          value: /etc/pki/tls/certs/workshop-ca.crt
EOF
echo ""

echo "============================================"
echo " Key Takeaway:"
echo " trust-manager automatically distributes and"
echo " updates CA bundles when certificates rotate."
echo "============================================"
echo ""

echo "Cleanup (run after demo):"
echo "  oc delete bundle workshop-ca-bundle"
echo "  oc delete namespace trust-demo-app1 trust-demo-app2 trust-demo-app3"
