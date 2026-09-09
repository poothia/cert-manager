#!/usr/bin/env bash
# ACT 1, Step 1: Deploy app and create a plain Route (no cert-manager annotations)
set -euo pipefail

echo "==========================================="
echo " ACT 1: The Invisible Guardian"
echo "==========================================="
echo ""

echo "Step 1: Deploying the app..."
oc new-project custom-domain-demo 2>/dev/null || oc project custom-domain-demo

oc create deployment web-app \
  --image=registry.access.redhat.com/ubi9/httpd-24:latest \
  -n custom-domain-demo 2>/dev/null || true

oc expose deployment web-app --port=8080 -n custom-domain-demo 2>/dev/null || true

echo "Waiting for pod..."
oc rollout status deployment/web-app -n custom-domain-demo --timeout=60s

echo ""
echo "Step 2: Creating a plain Route (no cert-manager annotations)..."
oc create route edge web-app \
  --service=web-app \
  --insecure-policy=Redirect \
  -n custom-domain-demo 2>/dev/null || true

ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')
echo ""
echo "Route created: https://${ROUTE_HOST}"
echo ""

echo "Step 3: Checking what certificate the Route is serving..."
echo ""
curl -sv "https://${ROUTE_HOST}" 2>&1 | grep -E "subject:|issuer:|expire|subjectAltName|matched" | sed 's/^/  /'

echo ""
echo "==========================================="
echo " Notice: the cert subject is the WILDCARD:"
echo "   CN=*.apps.cluster-z8n9x.dyn.redhatworkshops.io"
echo ""
echo " This is the cluster's default cert, managed"
echo " by cert-manager at the infrastructure level."
echo "==========================================="
echo ""

echo "Step 4: Show the certificate resource behind this..."
echo ""
echo "  Certificate in openshift-ingress namespace:"
oc get certificate -n openshift-ingress --no-headers
echo ""
echo "  Certificate details:"
oc get secret cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -issuer -dates | sed 's/^/  /'
echo ""
echo "  Renewal:"
oc get certificate cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='  Renews at: {.status.renewalTime}{"\n"}'
echo ""

echo "==========================================="
echo " ACT 1 complete."
echo " Next: ./02-custom-domain.sh (Act 2)"
echo "==========================================="
