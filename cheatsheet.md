# cert-manager on OpenShift -- Cheat Sheet

## Quick Status Commands

```bash
oc get certificate -A                          # All certs, all namespaces
oc get clusterissuer                           # All cluster-wide issuers
oc get issuer -A                               # All namespace-scoped issuers
oc get certificaterequest -A                   # All pending/completed requests
oc get orders.acme.cert-manager.io -A          # ACME orders (if using ACME)
oc get challenges.acme.cert-manager.io -A      # ACME challenges in flight
oc get pods -n cert-manager                    # cert-manager workload pods
oc get pods -n cert-manager-operator           # Operator pod
```

## Certificate Inspection

```bash
# Decode and display full cert details
oc get secret <SECRET> -n <NS> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -text -noout

# Check expiry only
oc get secret <SECRET> -n <NS> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -enddate -noout

# Check issuer (who signed it)
oc get secret <SECRET> -n <NS> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -issuer -noout

# Check SAN (Subject Alternative Names)
oc get secret <SECRET> -n <NS> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -ext subjectAltName
```

## Logs

```bash
oc logs -n cert-manager deploy/cert-manager -f           # Controller (main)
oc logs -n cert-manager deploy/cert-manager-webhook -f   # Webhook
oc logs -n cert-manager deploy/cert-manager-cainjector -f # CA Injector
```

## Events

```bash
oc get events -n <NS> --field-selector reason=Issuing
oc get events -n <NS> --field-selector reason=IssueError
oc get events -n <NS> --sort-by='.lastTimestamp'
```

---

## Custom Resource Quick Reference

### ClusterIssuer (cluster-wide) / Issuer (namespace-scoped)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer          # or Issuer
metadata:
  name: my-issuer
spec:
  selfSigned: {}             # --- OR ---
  ca:
    secretName: ca-secret    # --- OR ---
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: acme-account-key
    solvers:
      - http01:
          ingress: {}
      - dns01:
          cloudDNS: {}       # or route53, cloudflare, rfc2136, etc.
```

### Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-cert
  namespace: my-ns
spec:
  secretName: my-tls-secret         # Where the cert+key are stored
  duration: 2160h                   # 90 days (default)
  renewBefore: 720h                 # 30 days before expiry
  isCA: false                       # true for CA certs
  commonName: my-app.example.com    # Optional (prefer dnsNames)
  dnsNames:                         # SANs
    - my-app.example.com
    - www.my-app.example.com
  ipAddresses:                      # Optional IP SANs
    - 10.0.0.1
  privateKey:
    algorithm: ECDSA                # RSA, ECDSA, or Ed25519
    size: 256                       # 256/384 for ECDSA, 2048/4096 for RSA
  issuerRef:
    name: my-issuer
    kind: ClusterIssuer             # or Issuer
    group: cert-manager.io
```

### Route Annotations (openshift-routes controller)

```yaml
metadata:
  annotations:
    cert-manager.io/issuer-name: my-issuer          # Required
    cert-manager.io/issuer-kind: ClusterIssuer      # Issuer or ClusterIssuer
    cert-manager.io/duration: 2160h                 # Optional
    cert-manager.io/renew-before: 720h              # Optional
    cert-manager.io/common-name: my-app.example.com # Optional
```

### Bundle (trust-manager, Tech Preview)

```yaml
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: my-bundle
spec:
  sources:
    - secret:
        name: root-ca-secret
        key: ca.crt
  target:
    configMap:
      key: ca-bundle.crt
    namespaceSelector:
      matchLabels:
        trust.cert-manager.io/inject: "true"
```

---

## Troubleshooting Flowchart

```
Certificate not Ready?
  |
  +--> oc describe certificate <name> -n <ns>
       |
       +--> Issuer not ready?
       |      +--> oc describe clusterissuer <name>
       |      +--> Check: secret exists? correct namespace? permissions?
       |
       +--> CertificateRequest pending?
       |      +--> oc get certificaterequest -n <ns>
       |      +--> oc describe certificaterequest <name>
       |
       +--> ACME Order/Challenge failing?
       |      +--> oc get orders -n <ns>
       |      +--> oc get challenges -n <ns>
       |      +--> DNS propagation? HTTP solver reachable? Rate limited?
       |
       +--> Webhook errors?
              +--> oc logs deploy/cert-manager-webhook -n cert-manager
              +--> Pod running? NetworkPolicy blocking port 10250?
```

---

## Key Links

| Resource | URL |
|----------|-----|
| Red Hat Docs (OCP 4.20) | https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/cert-manager-operator-for-red-hat-openshift |
| Upstream cert-manager | https://cert-manager.io/docs/ |
| openshift-routes controller | https://github.com/cert-manager/openshift-routes |
| trust-manager | https://cert-manager.io/docs/trust/trust-manager/ |
