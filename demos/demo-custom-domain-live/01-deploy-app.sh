#!/usr/bin/env bash
# ACT 1: Deploy app, create plain Route, show the wildcard cert
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
echo "Step 2: Creating a plain Route (no cert-manager involvement)..."
oc create route edge web-app \
  --service=web-app \
  --insecure-policy=Redirect \
  -n custom-domain-demo 2>/dev/null || true

ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')
ROUTER_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')

echo ""
echo "Route: https://${ROUTE_HOST}"
echo ""

echo "Step 3: What certificate is the Route serving?"
echo ""
echo | openssl s_client -servername "${ROUTE_HOST}" \
  -connect "${ROUTER_HOST}:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName | sed 's/^/  /'

echo ""
echo "==========================================="
echo " The cert subject is: CN=*.apps.cluster-z8n9x..."
echo " This is the SHARED WILDCARD -- cert-manager"
echo " issued it at the infrastructure level."
echo "==========================================="
echo ""

echo "Step 4: The Certificate resource behind this:"
oc get certificate -n openshift-ingress --no-headers
echo ""
oc get certificate cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='  Expires:  {.status.notAfter}{"\n"}  Renews at: {.status.renewalTime}{"\n"}'
echo ""
echo ""
echo "==========================================="
echo " ACT 1 complete."
echo " Next: ./02-create-route.sh"
echo "==========================================="
