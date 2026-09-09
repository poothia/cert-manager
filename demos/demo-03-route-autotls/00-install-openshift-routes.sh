#!/usr/bin/env bash
# Demo 3 - Step 1: Install the openshift-routes controller via Helm
#
# The openshift-routes controller watches Route objects for cert-manager
# annotations and automatically issues/attaches TLS certificates.
#
# Prerequisites: Helm 3 installed, oc logged in as cluster-admin.

set -euo pipefail

echo "============================================"
echo " Installing openshift-routes controller"
echo "============================================"
echo ""

# Check if Helm is available
if ! command -v helm &> /dev/null; then
  echo "ERROR: 'helm' command not found."
  echo "Install Helm 3: https://helm.sh/docs/intro/install/"
  exit 1
fi

echo "Adding the cert-manager Helm chart repository..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
echo ""

echo "Installing openshift-routes in the cert-manager namespace..."
helm install openshift-routes jetstack/cert-manager-openshift-routes \
  --namespace cert-manager \
  --wait \
  --timeout 120s
echo ""

echo "Verifying the openshift-routes pod..."
oc get pods -n cert-manager | grep openshift-routes
echo ""

echo "============================================"
echo " openshift-routes controller installed"
echo "============================================"
echo ""
echo "You can now annotate Route objects with:"
echo "  cert-manager.io/issuer-name: <issuer-name>"
echo "  cert-manager.io/issuer-kind: ClusterIssuer"
echo ""
echo "The controller will automatically issue and attach TLS certificates."
