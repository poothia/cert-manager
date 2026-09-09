#!/usr/bin/env bash
# Lab 0: Verify environment access
# Run this script to confirm your cluster access before starting the labs.

set -euo pipefail

echo "=== Lab 0: Environment Verification ==="
echo ""

echo "1. Checking oc CLI..."
if ! command -v oc &> /dev/null; then
  echo "   FAIL: 'oc' command not found. Install the OpenShift CLI first."
  exit 1
fi
echo "   OK: oc found at $(command -v oc)"
echo ""

echo "2. Checking cluster login..."
if ! oc whoami &> /dev/null; then
  echo "   FAIL: Not logged in. Run 'oc login <cluster-api-url>' first."
  exit 1
fi
CURRENT_USER=$(oc whoami)
echo "   OK: Logged in as ${CURRENT_USER}"
echo ""

echo "3. Checking cluster-admin privileges..."
if ! oc auth can-i create clusterissuer.cert-manager.io 2>/dev/null; then
  echo "   WARN: Cannot verify cert-manager CRD permissions (operator may not be installed yet)."
  echo "   Checking general cluster-admin..."
  if ! oc auth can-i '*' '*' --all-namespaces 2>/dev/null; then
    echo "   FAIL: You do not appear to have cluster-admin privileges."
    exit 1
  fi
fi
echo "   OK: cluster-admin confirmed"
echo ""

echo "4. Checking openssl..."
if ! command -v openssl &> /dev/null; then
  echo "   WARN: 'openssl' not found. You will need it to inspect certificates."
else
  echo "   OK: openssl found at $(command -v openssl)"
fi
echo ""

echo "5. Checking cluster version..."
oc get clusterversion version -o jsonpath='   Cluster: {.status.desired.version}{"\n"}'
echo ""

echo "6. Checking if cert-manager operator is installed..."
if oc get pods -n cert-manager-operator 2>/dev/null | grep -q Running; then
  echo "   OK: cert-manager operator is already installed."
  echo "   Workload pods:"
  oc get pods -n cert-manager --no-headers 2>/dev/null | sed 's/^/   /'
else
  echo "   INFO: cert-manager operator is NOT installed yet. You will install it in Lab 1 / Demo 1."
fi
echo ""

echo "=== Environment verification complete ==="
