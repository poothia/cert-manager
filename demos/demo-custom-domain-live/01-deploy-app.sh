#!/usr/bin/env bash
# Step 1: Deploy the sample HTTPD app
set -euo pipefail

echo "=== Step 1: Deploy the application ==="
echo ""

oc new-project custom-domain-demo 2>/dev/null || oc project custom-domain-demo

echo "Creating deployment..."
oc create deployment web-app \
  --image=registry.access.redhat.com/ubi9/httpd-24:latest \
  -n custom-domain-demo

echo "Exposing service..."
oc expose deployment web-app --port=8080 -n custom-domain-demo

echo ""
echo "Waiting for pod to be ready..."
oc rollout status deployment/web-app -n custom-domain-demo --timeout=60s

echo ""
echo "App is running:"
oc get pods -n custom-domain-demo --no-headers
echo ""
echo "Service:"
oc get svc web-app -n custom-domain-demo --no-headers
echo ""
echo "Next: run ./02-create-route.sh"
