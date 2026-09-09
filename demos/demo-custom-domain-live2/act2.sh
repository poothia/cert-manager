#!/usr/bin/env bash
# Act 2: Issue a dedicated certificate, wire it to the Route via externalCertificate.
set -euo pipefail

ROUTE_HOST=$(oc get route web-app -n demo -o jsonpath='{.spec.host}')
ROUTER=$(oc get route web-app -n demo -o jsonpath='{.status.ingress[0].routerCanonicalHostname}')

echo "=== Act 2: Three resources, done ==="
echo ""
echo "Hostname: ${ROUTE_HOST}"
echo ""

# Step 4 -- Create Certificate
echo "Step 4: Creating Certificate resource..."
cat <<EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-app-cert
  namespace: demo
spec:
  secretName: web-app-tls
  dnsNames:
    - ${ROUTE_HOST}
  issuerRef:
    name: acme-bifrost-production-ddns
    kind: ClusterIssuer
EOF
echo ""

echo "Waiting for cert-manager to issue the certificate (~30-60s)..."
for i in $(seq 1 60); do
  READY=$(oc get certificate web-app-cert -n demo \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
  if [ "$READY" = "True" ]; then
    echo ""
    echo "Certificate READY!"
    oc get certificate web-app-cert -n demo
    break
  fi
  printf "\r  Waiting... (%ds)" "$((i * 3))"
  sleep 3
done
echo ""

# Step 5 -- RBAC
echo "Step 5: Granting router read access to the Secret..."
oc create role secret-reader \
  --verb=get,list,watch \
  --resource=secrets \
  --resource-name=web-app-tls \
  -n demo 2>/dev/null || true
oc create rolebinding router-secret-reader \
  --role=secret-reader \
  --serviceaccount=openshift-ingress:router \
  -n demo 2>/dev/null || true
echo "  Done."
echo ""

# Step 6 -- Recreate Route with externalCertificate
echo "Step 6: Recreating Route with externalCertificate..."
oc delete route web-app -n demo 2>/dev/null || true

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: web-app
  namespace: demo
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

# Step 7 -- Verify
echo "Step 7: Verifying (waiting 5s for router reload)..."
sleep 5

echo ""
echo "--- BEFORE (shared wildcard) ---"
oc get secret cert-manager-ingress-cert -n openshift-ingress \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -ext subjectAltName | sed 's/^/  /'

echo ""
echo "--- AFTER (dedicated cert on this Route) ---"
echo | openssl s_client -servername "$ROUTE_HOST" -connect "$ROUTER:443" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName | sed 's/^/  /'

echo ""
echo "=== Demo complete. Cleanup: oc delete project demo ==="
