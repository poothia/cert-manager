#!/usr/bin/env bash
# ACT 2: Create a Certificate, grant RBAC, create Route with externalCertificate
set -euo pipefail

ROUTE_HOST=$(oc get route web-app -n custom-domain-demo -o jsonpath='{.spec.host}')

echo "==========================================="
echo " ACT 2: The Dedicated Certificate"
echo "==========================================="
echo ""
echo " Hostname: ${ROUTE_HOST}"
echo " Issuer:   acme-bifrost-production-ddns (Google Trust Services)"
echo " Method:   externalCertificate (OCP 4.22 GA, fully supported)"
echo ""

echo "Step 4: Creating a Certificate resource..."
cat <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-app-cert
  namespace: custom-domain-demo
spec:
  secretName: web-app-tls
  dnsNames:
    - ${ROUTE_HOST}
  issuerRef:
    name: acme-bifrost-production-ddns
    kind: ClusterIssuer
    group: cert-manager.io
EOF
echo ""

echo "Step 5: Waiting for cert-manager to issue the certificate..."
echo "(ACME flow: Order -> DNS Challenge -> Google signs -> Secret created)"
echo ""
for i in $(seq 1 60); do
  READY=$(oc get certificate web-app-cert -n custom-domain-demo \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
  if [ "$READY" = "True" ]; then
    echo ""
    echo "Certificate READY!"
    oc get certificate web-app-cert -n custom-domain-demo
    break
  fi
  ORDERS=$(oc get orders.acme.cert-manager.io -n custom-domain-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  CHALLENGES=$(oc get challenges.acme.cert-manager.io -n custom-domain-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
  printf "\r  ACME in progress [orders: %s | challenges: %s] (%ds)" "$ORDERS" "$CHALLENGES" "$((i * 3))"
  sleep 3
done
echo ""

echo ""
echo "Step 6: Granting router access to the Secret (RBAC)..."
oc create role secret-reader \
  --verb=get,list,watch \
  --resource=secrets \
  --resource-name=web-app-tls \
  -n custom-domain-demo 2>/dev/null || true

oc create rolebinding router-secret-reader \
  --role=secret-reader \
  --serviceaccount=openshift-ingress:router \
  -n custom-domain-demo 2>/dev/null || true
echo "  Role + RoleBinding created."
echo ""

echo "Step 7: Updating the Route with externalCertificate..."
oc delete route web-app -n custom-domain-demo 2>/dev/null || true

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: custom-domain-demo
spec:
  host: ${ROUTE_HOST}
  to:
    kind: Service
    name: web-app
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
    externalCertificate:
      name: web-app-tls
EOF

echo ""
echo "Route created with externalCertificate: web-app-tls"
echo ""
echo "Next: ./03-watch-and-verify.sh"
