#!/usr/bin/env bash
# Demo 1: Install the cert-manager Operator for Red Hat OpenShift via CLI
#
# This script applies the namespace, operator group, and subscription,
# then waits for all components to be ready.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo " Demo 1: Installing cert-manager Operator"
echo "============================================"
echo ""

echo "Step 1/4: Creating namespace..."
oc apply -f "${SCRIPT_DIR}/00-namespace.yaml"
echo ""

echo "Step 2/4: Creating OperatorGroup..."
oc apply -f "${SCRIPT_DIR}/01-operatorgroup.yaml"
echo ""

echo "Step 3/4: Creating Subscription..."
oc apply -f "${SCRIPT_DIR}/02-subscription.yaml"
echo ""

echo "Step 4/4: Waiting for operator pod to be ready..."
echo "(This typically takes 1-3 minutes)"
echo ""

for i in $(seq 1 36); do
  if oc get pods -n cert-manager-operator 2>/dev/null | grep -q "Running"; then
    echo ""
    echo "Operator pod is running:"
    oc get pods -n cert-manager-operator
    break
  fi
  printf "  Waiting... (%d/36)\r" "$i"
  sleep 5
done

echo ""
echo "Waiting for cert-manager workload pods..."
for i in $(seq 1 36); do
  RUNNING=$(oc get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || true)
  if [ "$RUNNING" -ge 3 ]; then
    echo ""
    echo "All cert-manager workload pods are running:"
    oc get pods -n cert-manager
    break
  fi
  printf "  Waiting for 3 pods... (%d running, attempt %d/36)\r" "$RUNNING" "$i"
  sleep 5
done

echo ""
echo "============================================"
echo " cert-manager Operator installation complete"
echo "============================================"
echo ""
echo "Namespaces:"
echo "  cert-manager-operator  -- operator lifecycle pod"
echo "  cert-manager           -- controller, webhook, cainjector"
echo ""
echo "Next: explore the CertManager CR:"
echo "  oc get certmanager cluster -o yaml"
