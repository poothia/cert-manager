#!/usr/bin/env bash
# Step 3: Create the Route with cert-manager annotations
set -euo pipefail

CUSTOM_DOMAIN="orders.apps.cluster-z8n9x.dyn.redhatworkshops.io"

echo "=== Step 3: Create Route with cert-manager annotations ==="
echo ""
echo "Custom domain: ${CUSTOM_DOMAIN}"
echo "Issuer:        acme-bifrost-production-ddns (Google Trust Services)"
echo ""

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: custom-domain-demo
  annotations:
    cert-manager.io/issuer-name: acme-bifrost-production-ddns
    cert-manager.io/issuer-kind: ClusterIssuer
spec:
  host: ${CUSTOM_DOMAIN}
  to:
    kind: Service
    name: web-app
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

echo ""
echo "Route created. cert-manager is now issuing the certificate..."
echo ""
echo "Next: run ./03-watch-and-verify.sh"
echo ""
echo "Or watch manually:"
echo "  Terminal 1:  oc get certificate -n custom-domain-demo -w"
echo "  Terminal 2:  oc get orders.acme.cert-manager.io -n custom-domain-demo -w"
