#!/usr/bin/env bash
# ACT 2: Create a Route with a custom domain + cert-manager annotations
set -euo pipefail

CUSTOM_DOMAIN="orders.apps.cluster-z8n9x.dyn.redhatworkshops.io"

echo "==========================================="
echo " ACT 2: The Custom Domain"
echo "==========================================="
echo ""

echo "Step 5: Removing the old Route..."
oc delete route web-app -n custom-domain-demo 2>/dev/null || true
echo ""

echo "Step 6: Creating Route with cert-manager annotations..."
echo ""
echo "  Hostname: ${CUSTOM_DOMAIN}"
echo "  Issuer:   acme-bifrost-production-ddns (Google Trust Services)"
echo "  Annotations:"
echo "    cert-manager.io/issuer-name: acme-bifrost-production-ddns"
echo "    cert-manager.io/issuer-kind: ClusterIssuer"
echo ""

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app-custom
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
echo "Route created. cert-manager is now issuing a DEDICATED certificate..."
echo ""
echo "Next: ./03-watch-and-verify.sh"
echo ""
echo "Or watch manually in split terminals:"
echo "  Terminal 1:  oc get certificate -n custom-domain-demo -w"
echo "  Terminal 2:  oc get orders.acme.cert-manager.io -n custom-domain-demo -w"
