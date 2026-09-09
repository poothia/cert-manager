#!/usr/bin/env bash
# Demo 3 - Step 2: Deploy a sample app and create an annotated Route
#
# This script deploys an HTTPD app and creates a Route with cert-manager
# annotations so the openshift-routes controller issues a cert automatically.

set -euo pipefail

NAMESPACE="route-demo"
APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.cluster.example.com")
ROUTE_HOST="route-demo.${APPS_DOMAIN}"

echo "============================================"
echo " Demo 3: Auto-TLS on OpenShift Routes"
echo "============================================"
echo ""
echo "Cluster apps domain: ${APPS_DOMAIN}"
echo "Route hostname:      ${ROUTE_HOST}"
echo ""

echo "Creating namespace ${NAMESPACE}..."
oc new-project "${NAMESPACE}" 2>/dev/null || oc project "${NAMESPACE}"
echo ""

echo "Deploying sample HTTPD app..."
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: route-demo-app
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: route-demo-app
  template:
    metadata:
      labels:
        app: route-demo-app
    spec:
      containers:
        - name: httpd
          image: registry.access.redhat.com/ubi9/httpd-24:latest
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: route-demo-app
  namespace: ${NAMESPACE}
spec:
  selector:
    app: route-demo-app
  ports:
    - port: 8080
      targetPort: 8080
EOF
echo ""

echo "Waiting for pod to be ready..."
oc rollout status deployment/route-demo-app -n "${NAMESPACE}" --timeout=60s
echo ""

echo "Creating annotated Route (cert-manager will issue TLS automatically)..."
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: route-demo-app
  namespace: ${NAMESPACE}
  annotations:
    cert-manager.io/issuer-name: ca-issuer
    cert-manager.io/issuer-kind: ClusterIssuer
    cert-manager.io/duration: "2160h"
    cert-manager.io/renew-before: "720h"
spec:
  host: ${ROUTE_HOST}
  to:
    kind: Service
    name: route-demo-app
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF
echo ""

echo "Watching for TLS certificate to be populated on the Route..."
echo "(Press Ctrl+C when you see the certificate appear)"
echo ""
echo "Tip: In another terminal, run:"
echo "  oc get certificate -n ${NAMESPACE} -w"
echo ""

sleep 5
echo "Route TLS status:"
oc get route route-demo-app -n "${NAMESPACE}" -o jsonpath='{.spec.tls}' | python3 -m json.tool 2>/dev/null || \
  oc get route route-demo-app -n "${NAMESPACE}" -o yaml | grep -A 20 "tls:"

echo ""
echo "Route URL: https://${ROUTE_HOST}"
