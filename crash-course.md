# cert-manager on OpenShift -- Personal Crash Course

> **Purpose**: This is your private study guide to get hands-on confident with cert-manager
> before you deliver the workshop. Budget 4-6 hours total.

---

## Phase 1: Concepts (1-2 hours reading)

### Required Reading (in order)

1. **[Red Hat Blog: cert-manager Operator on OpenShift](https://www.redhat.com/en/blog/cert-manager-operator-openshift)**
   End-to-end walkthrough with Web Console screenshots -- install, CertManager CR, self-signed cert.

2. **[Official Red Hat Docs -- OCP 4.20 Chapter 9](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/cert-manager-operator-for-red-hat-openshift)**
   The authoritative reference. Focus on sections 9.1 (overview), 9.3 (installing), 9.7 (configuring issuers), 9.8 (configuring certificates).

3. **[Paul Bastide: Self-signed certs on OCP (Jan 2026)](https://bastide.org/2026/01/16/cert-manager-for-red-hat-openshift-using-self-signed-certs-in-your-cluster/)**
   Practical CLI-only walkthrough: install, self-signed chain, CA chain, trust bundles.

4. **[Red Hat Developer: mTLS with trust-manager (Jun 2026)](https://developers.redhat.com/articles/2026/06/25/implement-mtls-and-zero-trust-cert-manager-and-trust-manager)**
   Covers trust-manager (Tech Preview), Bundle CR, and mTLS patterns.

### Key Concepts to Internalize

#### What is cert-manager?

cert-manager is a Kubernetes-native controller that automates the lifecycle of X.509 (TLS/SSL) certificates. On OpenShift, Red Hat ships it as a supported operator via OperatorHub.

#### The Custom Resource Model

```
ClusterIssuer / Issuer          (HOW to get certs -- the "certificate authority" config)
        |
        v
    Certificate                 (WHAT cert you want -- DNS names, duration, secret name)
        |
        v
  CertificateRequest            (auto-created "order ticket" for the issuer to process)
        |
        v
     Secret                     (the OUTPUT -- tls.crt, tls.key, ca.crt stored here)
```

- **Issuer** -- namespace-scoped. Can only issue certs within its own namespace.
- **ClusterIssuer** -- cluster-wide. Any namespace can reference it.
- **Certificate** -- your desired state. You declare DNS names, duration, secret name, and which issuer to use. cert-manager reconciles it.
- **CertificateRequest** -- created automatically when a Certificate needs issuance. Think of it as the internal "work order."
- **Order** / **Challenge** -- ACME-specific resources. An Order represents a request to an ACME server; Challenges represent the validation steps (HTTP-01 or DNS-01).
- **Secret** -- the output. cert-manager stores the signed cert + private key in a standard `kubernetes.io/tls` Secret.

#### Renewal

Automatic. By default, cert-manager renews at 2/3 of the certificate's lifetime. No cron jobs, no manual intervention. You can override this with `renewBefore` on the Certificate spec.

#### Issuer Types (know these cold)

| Issuer Type | Use Case | Needs External Infra? |
|-------------|----------|----------------------|
| **SelfSigned** | Bootstrapping a root CA, dev/test | No |
| **CA** | Internal PKI -- signs certs using a CA key stored in a Secret | No (key in cluster) |
| **ACME (HTTP-01)** | Public certs from Let's Encrypt or private ACME (IdM) | Yes (HTTP endpoint reachable) |
| **ACME (DNS-01)** | Wildcard certs, environments where HTTP isn't reachable | Yes (DNS API access) |
| **Vault** | HashiCorp Vault PKI secrets engine | Yes (Vault instance) |
| **Venafi** | Enterprise PKI with Venafi Trust Protection Platform or Cloud | Yes (Venafi) |
| **External** | Any custom issuer via the External Issuer interface | Depends |

#### Operator Architecture

When you install the Red Hat cert-manager operator, OLM deploys:

1. **cert-manager-operator** pod (in `cert-manager-operator` namespace) -- manages the lifecycle of the components below.
2. **cert-manager controller** (in `cert-manager` namespace) -- the main reconciliation loop.
3. **cert-manager webhook** (in `cert-manager` namespace) -- validates and mutates cert-manager CRs.
4. **cert-manager cainjector** (in `cert-manager` namespace) -- injects CA bundles into webhook configurations and CRDs.

The operator is configured via the `CertManager` CR (kind: CertManager). You use it to set CPU/memory overrides, log levels, scheduling constraints, and feature flags.

---

## Phase 2: Hands-On Practice (2-3 hours)

> Spin up a cluster: RHPDS, demo.redhat.com, CRC, or your own lab.
> You need cluster-admin privileges.

### Exercise A -- Install the Operator (30 min)

#### Option 1: Web Console

1. Log into the OpenShift Web Console as cluster-admin.
2. Navigate to **Operators > OperatorHub**.
3. Search for **cert-manager Operator for Red Hat OpenShift**.
4. Click **Install**. Accept defaults (AllNamespaces mode, stable-v1 channel, Automatic approval).
5. Wait for the operator to show **Succeeded** status.
6. Click the operator, go to the **CertManager** tab, click **Create CertManager**.
7. Accept default YAML -- click **Create**.

#### Option 2: CLI

Apply this multi-document YAML:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
spec:
  targetNamespaces: []
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: cert-manager-operator
spec:
  channel: stable-v1
  installPlanApproval: Automatic
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

```bash
oc apply -f install-operator.yaml
```

#### Verification

```bash
# Wait for operator pod
oc get pods -n cert-manager-operator -w

# Once the operator is running, it deploys the workload pods:
oc get pods -n cert-manager
# Expected: cert-manager-<hash>, cert-manager-webhook-<hash>, cert-manager-cainjector-<hash>

# Check the CertManager CR
oc get certmanager cluster -o yaml
```

All three pods in `cert-manager` namespace should be **Running** and **1/1 Ready**.

---

### Exercise B -- Self-Signed to CA Chain (30 min)

This is the most common pattern for internal PKI: bootstrap a self-signed root, then use it as a CA to issue leaf certs.

#### Step 1: Create a SelfSigned ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

```bash
oc apply -f 00-clusterissuer-selfsigned.yaml
oc get clusterissuer selfsigned-issuer
# STATUS should be "True" / Ready
```

#### Step 2: Create a Root CA Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
spec:
  isCA: true
  secretName: root-ca-secret
  commonName: "Workshop Root CA"
  duration: 87600h       # 10 years
  renewBefore: 8760h     # renew 1 year before expiry
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io
```

```bash
oc apply -f 01-certificate-root-ca.yaml
oc get certificate root-ca -n cert-manager
# READY should be "True"

# Inspect the CA cert
oc get secret root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -text -noout
# Look for: Issuer = Subject = "Workshop Root CA", CA:TRUE
```

#### Step 3: Create a CA ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: root-ca-secret
```

```bash
oc apply -f 02-clusterissuer-ca.yaml
oc get clusterissuer ca-issuer
# STATUS should be "True" / Ready
```

#### Step 4: Issue a Leaf Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-cert
  namespace: default
spec:
  secretName: my-app-tls
  duration: 2160h        # 90 days
  renewBefore: 720h      # renew 30 days before expiry
  dnsNames:
    - my-app.apps.cluster.example.com
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
    group: cert-manager.io
```

```bash
oc apply -f 03-certificate-leaf.yaml
oc get certificate my-app-cert -n default
# READY = True

# Inspect the leaf cert
oc get secret my-app-tls -n default -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -text -noout
# Issuer should be "Workshop Root CA"
# Subject Alternative Name should include my-app.apps.cluster.example.com
```

**What you learned**: The self-signed issuer bootstraps a CA cert. The CA issuer then signs leaf certs. This two-tier hierarchy is the bread and butter of internal PKI on OpenShift.

---

### Exercise C -- Secure an App with TLS (30 min)

#### Deploy a sample app

```bash
oc new-project workshop-demo
oc new-app httpd --name=secure-app -n workshop-demo
oc expose svc/secure-app -n workshop-demo
```

#### Issue a certificate for it

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: secure-app-cert
  namespace: workshop-demo
spec:
  secretName: secure-app-tls
  duration: 2160h
  dnsNames:
    - secure-app-workshop-demo.apps.cluster.example.com
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
```

```bash
oc apply -f secure-app-cert.yaml
oc get certificate secure-app-cert -n workshop-demo
```

#### Create a passthrough Route using the cert

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: secure-app-tls
  namespace: workshop-demo
spec:
  host: secure-app-workshop-demo.apps.cluster.example.com
  to:
    kind: Service
    name: secure-app
  tls:
    termination: edge
    certificate: |
      # You would extract from the secret, or use the openshift-routes controller
    key: |
      # Extracted from secret
```

Alternatively (much easier), use the **openshift-routes** controller annotations covered in Exercise E below.

#### Verify

```bash
# Extract the CA cert to verify the chain
oc get secret root-ca-secret -n cert-manager -o jsonpath='{.data.ca\.crt}' \
  | base64 -d > /tmp/workshop-ca.crt

curl --cacert /tmp/workshop-ca.crt \
  https://secure-app-workshop-demo.apps.cluster.example.com
```

---

### Exercise D -- Watch Automatic Renewal (15 min)

Create a certificate with a very short lifetime to observe renewal in real time:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: short-lived-cert
  namespace: default
spec:
  secretName: short-lived-tls
  duration: 1h
  renewBefore: 50m
  dnsNames:
    - short-lived.apps.cluster.example.com
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
```

```bash
oc apply -f short-lived-cert.yaml

# Watch the certificate status -- it will renew ~10 min after issuance
oc get certificate short-lived-cert -n default -w

# In another terminal, watch events:
oc get events -n default --field-selector reason=Issuing -w
```

You should see the certificate flip from `Ready=True` to issuing and back to `Ready=True` with a new `Not After` timestamp. This is the core value proposition: zero-touch renewal.

---

### Exercise E -- trust-manager (30 min)

#### Enable trust-manager on the operator subscription

```bash
oc -n cert-manager-operator patch subscription openshift-cert-manager-operator \
  --type merge \
  -p '{"spec":{"config":{"env":[{"name":"UNSUPPORTED_ADDON_FEATURES","value":"TrustManager=true"}]}}}'
```

Wait for the trust-manager pod to appear:

```bash
oc get pods -n cert-manager -w
# A new pod: trust-manager-<hash> should appear
```

#### Create a Bundle

```yaml
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: workshop-ca-bundle
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

```bash
oc apply -f bundle.yaml

# Label a namespace to receive the bundle
oc label namespace workshop-demo trust.cert-manager.io/inject=true

# Check that the ConfigMap appeared
oc get configmap workshop-ca-bundle -n workshop-demo
oc get configmap workshop-ca-bundle -n workshop-demo -o jsonpath='{.data.ca-bundle\.crt}'
```

The ConfigMap should contain the PEM-encoded CA certificate, ready to be mounted by any pod in that namespace.

---

## Phase 3: Troubleshooting Muscle Memory (30 min)

Practice these commands until they are second nature:

```bash
# ---- STATUS CHECKS ----

# All certificates across the cluster
oc get certificate -A

# Detailed status of a specific certificate
oc describe certificate <name> -n <namespace>

# All issuers / cluster issuers
oc get clusterissuer
oc get issuer -A

# Issuer readiness detail
oc describe clusterissuer <name>

# Certificate requests (the "order tickets")
oc get certificaterequest -A

# ---- LOGS ----

# Main controller (most issues surface here)
oc logs -n cert-manager deploy/cert-manager -f

# Webhook (for admission/validation errors)
oc logs -n cert-manager deploy/cert-manager-webhook -f

# CA injector
oc logs -n cert-manager deploy/cert-manager-cainjector -f

# ---- CERTIFICATE INSPECTION ----

# Decode the certificate from a Secret
oc get secret <name> -n <ns> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -text -noout

# Check expiry date only
oc get secret <name> -n <ns> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -enddate -noout

# Check the full chain
oc get secret <name> -n <ns> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl crl2pkcs7 -nocrl -certfile /dev/stdin \
  | openssl pkcs7 -print_certs -noout

# ---- EVENTS ----

# Certificate-related events in a namespace
oc get events -n <ns> --field-selector reason=Issuing
oc get events -n <ns> --field-selector reason=IssueError

# ---- COMMON FAILURE MODES ----
# 1. Issuer not ready     --> oc describe clusterissuer <name> -- check Status.Conditions
# 2. Secret not found     --> CA issuer referencing a secret that doesn't exist or is in the wrong namespace
# 3. Webhook timeout      --> cert-manager-webhook pod not running or network policy blocking it
# 4. DNS propagation      --> ACME DNS-01 challenge failing because DNS hasn't propagated yet
# 5. RBAC                 --> cert-manager SA missing permissions to read secrets across namespaces
```

---

## Phase 4: Key Reference Links

| Resource | URL |
|----------|-----|
| Red Hat Docs: cert-manager Operator (OCP 4.20) | https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/cert-manager-operator-for-red-hat-openshift |
| Red Hat Developer: mTLS with trust-manager | https://developers.redhat.com/articles/2026/06/25/implement-mtls-and-zero-trust-cert-manager-and-trust-manager |
| Red Hat Developer: ACME + DNS challenge | https://developers.redhat.com/articles/2025/08/01/automatic-certificate-provisioning-cert-manager-and-dns-challenge |
| Red Hat Developer: IdM + cert-manager | https://developers.redhat.com/articles/2024/12/17/automatic-certificate-issuing-idm-and-cert-manager-operator-openshift |
| cert-manager/openshift-routes GitHub | https://github.com/cert-manager/openshift-routes |
| Upstream cert-manager docs | https://cert-manager.io/docs/ |
| Red Hat Learning: Simplify cert management | https://developers.redhat.com/learning/learn:openshift:simplify-certificate-management-openshift-across-multiple-architectures |

---

## Phase 5: Dry-Run the Workshop (1 hour)

After completing Phases 1-3, do a timed rehearsal:

1. **Reset your cluster** -- uninstall the operator, delete all cert-manager CRs and namespaces.
2. **Run through Demo 1** (install) in under 10 minutes.
3. **Run through Lab 1** (self-signed chain) in under 15 minutes.
4. **Run through Demo 2** (ACME or CA-based app cert) in under 10 minutes.
5. **Run through Demo 3** (Route annotation) in under 10 minutes.
6. **Run through Demo 4** (trust-manager) in under 10 minutes.

If any demo takes longer than its slot, identify the bottleneck (slow cluster, DNS propagation, typos) and prepare a mitigation (pre-baked resources, fallback to CA issuer, pre-recorded video segment).

**You are now ready to deliver the workshop.**
