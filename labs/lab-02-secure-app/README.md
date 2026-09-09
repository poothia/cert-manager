# Lab 2: Securing an Application with a CA-Issued Certificate

## Objective

Deploy an HTTPD application, issue a TLS certificate from the CA ClusterIssuer (created in Lab 1), and expose it over HTTPS via an OpenShift Route.

## Prerequisites

- Lab 1 completed (selfsigned-issuer, root-ca, and ca-issuer exist)

## Steps

### Step 1 -- Create the project namespace

```bash
oc new-project workshop-demo
```

### Step 2 -- Deploy the application

```bash
oc apply -f 00-deployment-httpd.yaml
oc apply -f 01-service.yaml
oc get pods -n workshop-demo -w
# Wait until the pod is Running
```

### Step 3 -- Request a TLS certificate

Edit `02-certificate.yaml` and set the `dnsNames` to match your cluster:

```bash
# Find your cluster apps domain:
oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'

# Edit the file, then apply:
oc apply -f 02-certificate.yaml
oc get certificate secure-app-cert -n workshop-demo
# READY = True
```

### Step 4 -- Create the Route

Edit `03-route-edge.yaml` to set the correct `host`, then:

```bash
oc apply -f 03-route-edge.yaml
```

Now patch the Route to use the cert-manager-issued certificate:

```bash
# Extract cert and key from the secret
CERT=$(oc get secret secure-app-tls -n workshop-demo -o jsonpath='{.data.tls\.crt}' | base64 -d)
KEY=$(oc get secret secure-app-tls -n workshop-demo -o jsonpath='{.data.tls\.key}' | base64 -d)
CACERT=$(oc get secret secure-app-tls -n workshop-demo -o jsonpath='{.data.ca\.crt}' | base64 -d)

# Patch the route with the certificate
oc patch route secure-app -n workshop-demo --type merge -p "{
  \"spec\": {
    \"tls\": {
      \"certificate\": $(echo "$CERT" | jq -Rs .),
      \"key\": $(echo "$KEY" | jq -Rs .),
      \"caCertificate\": $(echo "$CACERT" | jq -Rs .)
    }
  }
}"
```

### Step 5 -- Verify HTTPS

```bash
# Extract the CA cert for verification
oc get secret root-ca-secret -n cert-manager \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/workshop-ca.crt

# Test the connection
ROUTE_HOST=$(oc get route secure-app -n workshop-demo -o jsonpath='{.spec.host}')
curl --cacert /tmp/workshop-ca.crt "https://${ROUTE_HOST}"
```

You should see the default HTTPD welcome page served over HTTPS, verified against the workshop CA.

## Cleanup

```bash
oc delete project workshop-demo
# This removes all resources in the namespace. The ClusterIssuers remain.
```
