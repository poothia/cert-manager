# Slide Deck Outline -- OpenShift cert-manager Workshop

> Use this outline to build your presentation deck.
> Each entry includes the slide number, title, and speaker notes / content bullets.
> Recommended: Red Hat branded template from the Partner Portal.

---

## Section 1: Opening (Slides 1-5)

### Slide 1 -- Title Slide

- **Title**: Automating Certificate Lifecycle on OpenShift with cert-manager
- **Subtitle**: Full-Day Hands-On Workshop
- **Presenter**: [Your Name], [Your Title], Red Hat
- **Date**: [Workshop Date]
- Red Hat + cert-manager logos

### Slide 2 -- Agenda Overview

- Block 1: Foundations (09:00-10:30)
- Block 2: Installation & First Certificate (10:30-12:00)
- Lunch (12:00-13:00)
- Block 3: Real-World Issuers (13:00-14:30)
- Block 4: Routes & Ingress (14:30-15:30)
- Block 5: trust-manager & Advanced (15:30-16:30)
- Block 6: Wrap-Up (16:30-17:00)

### Slide 3 -- Speaker Bio

- Brief professional background
- Relevant certifications (RHCE, CKA, etc.)
- Contact info

### Slide 4 -- Workshop Objectives

By the end of this workshop, attendees will be able to:
1. Install and configure the cert-manager Operator for Red Hat OpenShift
2. Build internal PKI using self-signed and CA issuers
3. Integrate with external CAs (ACME / Let's Encrypt)
4. Automate TLS on OpenShift Routes
5. Distribute trust bundles with trust-manager
6. Troubleshoot common certificate issues

### Slide 5 -- Prerequisites & Lab Access

- OpenShift 4.20+ cluster with cluster-admin
- `oc` CLI installed and authenticated
- Lab guide URL / Git repo link
- Wi-Fi credentials, support channel

---

## Section 2: TLS/PKI Primer (Slides 6-15)

### Slide 6 -- Why TLS Matters

- Encryption in transit: protect data from eavesdropping
- Authentication: prove the server is who it claims to be
- Integrity: detect tampering
- Compliance: PCI-DSS, HIPAA, SOC2 all require TLS

### Slide 7 -- X.509 Certificate Anatomy

- Diagram of a certificate: Subject, Issuer, Serial, Validity, Public Key, Extensions, Signature
- Speaker notes: walk through each field

### Slide 8 -- Public Key Cryptography (Simplified)

- Asymmetric keys: public key encrypts, private key decrypts
- Digital signatures: private key signs, public key verifies
- Key algorithms: RSA (2048/4096), ECDSA (P-256/P-384), Ed25519
- Speaker notes: don't go too deep -- focus on "why does the private key need to stay secret?"

### Slide 9 -- Certificate Authority Hierarchy

- Diagram: Root CA --> Intermediate CA --> Leaf Certificate
- Root CA: self-signed, highly protected (offline ideally)
- Intermediate CA: signs leaf certs, limits blast radius if compromised
- Leaf cert: what your application actually uses
- Trust chain: browser/OS trusts root, root signed intermediate, intermediate signed leaf

### Slide 10 -- The Trust Problem

- How does a client know to trust a cert? Trust stores (OS, browser, JVM)
- Public CAs (Let's Encrypt, DigiCert) vs. Private CAs (internal PKI)
- Speaker notes: "In Kubernetes, every namespace might need your internal CA bundle"

### Slide 11 -- Manual Certificate Management Pain Points

- Spreadsheets tracking expiry dates
- Outages caused by expired certificates (real-world examples: Microsoft Teams 2020, Equifax)
- Manual CSR generation, signing, distribution
- No audit trail, no policy enforcement
- Toil scales linearly with the number of services

### Slide 12 -- The Promise of Automation

- Declare what you need, the system handles the rest
- Automatic renewal -- no more 3 AM pages
- Policy as code -- enforce key sizes, durations, allowed issuers
- Audit trail via Kubernetes events and resources
- Self-service for developers

### Slide 13 -- cert-manager: Certificates-as-a-Service

- Open source project, CNCF incubating
- Kubernetes-native: CRDs, controllers, reconciliation loops
- Pluggable issuer architecture: self-signed, CA, ACME, Vault, Venafi, external
- 100M+ downloads, used by the majority of Kubernetes adopters
- Red Hat ships a supported operator on OperatorHub

### Slide 14 -- cert-manager on OpenShift: What Red Hat Provides

- Fully supported operator with SLA
- Tested and validated against each OCP release
- `stable-v1` update channel tracks latest certified version
- Current version: v1.20.0 (July 2026), based on upstream v1.20.3
- Additional features: trust-manager (Tech Preview), OpenShift-specific integrations
- Support via Red Hat Customer Portal

### Slide 15 -- Section Recap: Key Takeaways

- TLS certificates are the backbone of secure communication
- Manual management does not scale
- cert-manager automates the entire certificate lifecycle
- Red Hat provides an enterprise-supported version for OpenShift

---

## Section 3: Architecture Deep Dive (Slides 16-25)

### Slide 16 -- cert-manager Architecture Overview

- Diagram: Controller, Webhook, CA Injector -- all in `cert-manager` namespace
- Operator pod in `cert-manager-operator` namespace manages their lifecycle
- Speaker notes: draw this on whiteboard if possible

### Slide 17 -- The Controller

- Core reconciliation loop
- Watches Certificate, CertificateRequest, Issuer/ClusterIssuer resources
- Responsible for: creating CertificateRequests, storing certs in Secrets, triggering renewals
- Runs as a Deployment with leader election

### Slide 18 -- The Webhook

- Validating and mutating admission webhook
- Ensures CRs are well-formed before they hit the API server
- Common issue: if the webhook pod is down, cert-manager CRs cannot be created/updated

### Slide 19 -- The CA Injector

- Injects CA bundles into:
  - `ValidatingWebhookConfiguration`
  - `MutatingWebhookConfiguration`
  - `CustomResourceDefinition` conversion webhooks
  - `APIService` resources
- Uses annotations to determine which resources to inject

### Slide 20 -- Custom Resource Model (Diagram)

```
Issuer/ClusterIssuer  --configures-->  Certificate
                                          |
                                          | creates
                                          v
                                   CertificateRequest
                                          |
                                          | (ACME only) creates
                                          v
                                        Order
                                          |
                                          | creates
                                          v
                                      Challenge(s)
                                          |
                                          | (solved) completes
                                          v
                                        Secret
                                    (tls.crt + tls.key)
```

### Slide 21 -- Issuer vs ClusterIssuer

- **Issuer**: namespace-scoped. Can only issue certs within its own namespace.
- **ClusterIssuer**: cluster-wide. Any namespace can reference it.
- Best practice: use ClusterIssuer for shared CAs, Issuer for team-specific issuers
- Speaker notes: "If a team has their own Vault PKI mount, use a namespace Issuer"

### Slide 22 -- Certificate Resource Deep Dive

- Key fields: `secretName`, `dnsNames`, `duration`, `renewBefore`, `issuerRef`, `privateKey`
- `isCA: true` for CA certificates
- `usages` for extended key usage (server auth, client auth)
- cert-manager creates the Secret automatically when the cert is issued

### Slide 23 -- The Reconciliation Loop

- Step 1: User creates/updates a Certificate resource
- Step 2: Controller detects the change, creates a CertificateRequest
- Step 3: The appropriate issuer processes the request (sign locally or call external CA)
- Step 4: Signed cert is stored in the target Secret
- Step 5: Controller monitors the cert -- when renewal threshold is reached, repeat from Step 2
- All state transitions visible via `oc describe certificate` and Kubernetes events

### Slide 24 -- Red Hat Operator Lifecycle

- Installed via OLM (Operator Lifecycle Manager)
- Subscription to `redhat-operators` catalog
- `stable-v1` channel: latest stable release
- `CertManager` CR: customize controller, webhook, cainjector settings
  - CPU/memory overrides
  - Log verbosity
  - Scheduling (node selectors, tolerations)
  - Environment variables

### Slide 25 -- Section Recap

- Three components: controller (brain), webhook (validation), cainjector (trust injection)
- Everything is a Kubernetes resource: declarative, auditable, GitOps-friendly
- The reconciliation loop handles issuance AND renewal automatically
- Red Hat operator adds enterprise lifecycle management on top

---

## Section 4: Issuer Types (Slides 26-35)

### Slide 26 -- Issuer Types Overview

- Table comparing all issuer types (same as cheatsheet)
- Color-code by use case: dev/test (green), staging (yellow), production (red)

### Slide 27 -- SelfSigned Issuer

- Simplest type: certificate signs itself
- Use case: bootstrapping a root CA, throwaway dev certs
- No external dependencies
- NOT for production leaf certs (browsers won't trust it)

### Slide 28 -- CA Issuer

- Signs certs using a CA private key stored in a Kubernetes Secret
- The most common pattern for internal PKI
- The Secret must exist in the same namespace as the issuer (or `cert-manager` namespace for ClusterIssuer)
- Two-tier pattern: SelfSigned -> Root CA cert -> CA Issuer -> Leaf certs

### Slide 29 -- ACME Protocol Explained

- Diagram: Client (cert-manager) <--> ACME Server (Let's Encrypt / IdM)
- Account registration (one-time)
- Order creation (per certificate)
- Challenge: prove you control the domain
- Finalize: ACME server issues the cert
- Speaker notes: "Think of it like a driving test -- you register, take the test, get the license"

### Slide 30 -- ACME HTTP-01 Challenge

- cert-manager creates a temporary HTTP server at `http://<domain>/.well-known/acme-challenge/<token>`
- ACME server makes an HTTP request to verify
- Pros: simple, works with any HTTP-reachable domain
- Cons: does NOT support wildcard certs, requires port 80 to be reachable

### Slide 31 -- ACME DNS-01 Challenge

- cert-manager creates a TXT DNS record: `_acme-challenge.<domain>`
- ACME server queries DNS to verify
- Pros: supports wildcard certs, domain doesn't need to be HTTP-reachable
- Cons: requires DNS API access (Cloudflare, Route53, Azure DNS, RFC2136, etc.)
- Speaker notes: "For OpenShift clusters behind a firewall, DNS-01 is often the only option"

### Slide 32 -- Vault Issuer

- Integrates with HashiCorp Vault PKI secrets engine
- Vault acts as the CA -- cert-manager requests certs via the Vault API
- Authentication methods: token, AppRole, Kubernetes SA
- Use case: organizations already using Vault for secrets management

### Slide 33 -- Venafi Issuer

- Integrates with Venafi Trust Protection Platform or Venafi as a Service
- Enterprise PKI management with policy enforcement
- Use case: large enterprises with existing Venafi infrastructure

### Slide 34 -- External Issuers

- Pluggable interface for any CA
- Examples: AWS Private CA, Google CAS, Smallstep, ADCS
- Installed as separate controllers that watch CertificateRequest resources
- Speaker notes: "If your CA has an API, someone has probably built an external issuer for it"

### Slide 35 -- Choosing the Right Issuer

- Decision tree diagram:
  - Internal only? -> CA Issuer (or Vault)
  - Public trust needed? -> ACME with Let's Encrypt
  - Enterprise PKI? -> Venafi or Vault
  - Dev/test? -> SelfSigned
  - Air-gapped? -> CA Issuer or Vault (no external calls needed)

---

## Section 5: OpenShift Routes Integration (Slides 36-45)

### Slide 36 -- The Route TLS Challenge

- OpenShift Routes have built-in TLS termination (edge, passthrough, reencrypt)
- By default, routes use the cluster's wildcard certificate (self-signed)
- Custom certificates per Route require manual cert injection
- How do we automate this?

### Slide 37 -- openshift-routes Controller

- Open source project: github.com/cert-manager/openshift-routes
- Watches Route objects for cert-manager annotations
- Automatically creates Certificate resources and populates Route TLS fields
- Installed alongside cert-manager via Helm

### Slide 38 -- Route Annotations Reference

- `cert-manager.io/issuer-name` (required)
- `cert-manager.io/issuer-kind` (default: Issuer)
- `cert-manager.io/duration` (default: 90d)
- `cert-manager.io/renew-before` (default: 1/3 of duration)
- `cert-manager.io/common-name`, `cert-manager.io/alt-names`, etc.

### Slide 39 -- How It Works (Flow Diagram)

1. User creates a Route with cert-manager annotations
2. openshift-routes controller detects the annotation
3. Controller creates a Certificate resource
4. cert-manager issues the cert via the referenced issuer
5. openshift-routes controller reads the Secret
6. Controller patches the Route's `spec.tls` with the cert and key
7. Router pod picks up the change, starts serving the new cert
8. On renewal, the process repeats automatically

### Slide 40 -- Demo 3 Preview: What You Will See

- Install the controller
- Annotate a Route
- Watch it get its TLS certificate automatically
- Screenshots / expected output

### Slide 41 -- Replacing the Default Ingress Certificate

- The default IngressController uses a self-signed wildcard cert
- Browsers show "Not Secure" for all routes
- We can replace it with a cert-manager-managed certificate
- Steps: create Certificate in openshift-ingress, patch IngressController

### Slide 42 -- Wildcard Cert for the IngressController

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-ingress-cert
  namespace: openshift-ingress
spec:
  secretName: router-certs-custom
  dnsNames:
    - "*.apps.cluster.example.com"
  issuerRef:
    name: letsencrypt-prod   # or ca-issuer
    kind: ClusterIssuer
```

### Slide 43 -- Patching the IngressController

```bash
oc patch ingresscontroller default \
  -n openshift-ingress-operator \
  --type merge \
  -p '{"spec":{"defaultCertificate":{"name":"router-certs-custom"}}}'
```

- Router pods restart with the new certificate
- All routes without explicit certs now use the new wildcard

### Slide 44 -- Edge vs Passthrough vs Reencrypt

- **Edge**: Router terminates TLS, forwards HTTP to pod. Cert on Route.
- **Passthrough**: Router passes encrypted traffic directly to pod. Cert in pod.
- **Reencrypt**: Router terminates TLS, re-encrypts to pod. Cert on Route + cert in pod.
- cert-manager can manage certs for all three modes:
  - Edge/Reencrypt: via openshift-routes annotations or manual Secret extraction
  - Passthrough: mount the Secret directly into the pod

### Slide 45 -- Section Recap

- openshift-routes controller bridges cert-manager and OpenShift Routes
- Simple annotations trigger automatic cert issuance
- Wildcard certs can replace the default IngressController certificate
- All three TLS termination modes are supported

---

## Section 6: trust-manager (Slides 46-50)

### Slide 46 -- The Trust Distribution Problem

- Your internal CA issues certs -- but how do pods trust them?
- Every namespace needs a copy of the CA bundle
- Manual: create ConfigMap in each namespace, update on rotation -- doesn't scale
- trust-manager: automates this

### Slide 47 -- trust-manager Architecture

- Technology Preview add-on to the cert-manager operator
- Introduces the `Bundle` CRD
- Sources: Secrets, ConfigMaps, default OS CAs (`useDefaultCAs`)
- Targets: ConfigMap distributed to selected namespaces
- Namespace selection via label selectors

### Slide 48 -- Bundle Resource

```yaml
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: my-ca-bundle
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

### Slide 49 -- Automatic Rotation

- When cert-manager rotates the CA cert (in root-ca-secret), trust-manager detects the change
- It automatically regenerates and redistributes the Bundle to all target namespaces
- No manual intervention needed
- This completes the zero-touch automation story: issue + renew + distribute

### Slide 50 -- Enabling trust-manager

- Patch the operator subscription: `UNSUPPORTED_ADDON_FEATURES=TrustManager=true`
- As of v1.19+, no longer requires `TechPreviewNoUpgrade` FeatureSet
- trust-manager pod appears in the `cert-manager` namespace
- Technology Preview: use in non-production or with awareness of support status

---

## Section 7: Advanced Topics (Slides 51-55)

### Slide 51 -- Monitoring and Alerting

- cert-manager exposes Prometheus metrics on `:9402/metrics`
- Key metrics:
  - `certmanager_certificate_expiration_timestamp_seconds` -- time of expiry
  - `certmanager_certificate_ready_status` -- is the cert valid?
  - `certmanager_certificate_renewal_timestamp_seconds` -- when will it renew?
- Sample PrometheusRule alerts:
  - Certificate expiring within 7 days
  - Certificate not ready for more than 15 minutes
  - CertificateRequest pending for more than 30 minutes

### Slide 52 -- Air-Gapped / Disconnected Clusters

- Configure egress proxy on the cert-manager operator
- Use CA issuer or Vault (no external calls needed)
- For ACME: consider IdM as an internal ACME server (RFC 8555)
- Mirror container images to internal registry
- trust-manager with `useDefaultCAs: false` and explicit sources

### Slide 53 -- Performance Tuning

- `CertManager` CR: override CPU/memory for controller, webhook, cainjector
- `--certificate-request-minimum-backoff-duration` -- controls retry backoff
- `--max-concurrent-challenges` -- for high-volume ACME environments
- `--dns01-recursive-nameservers` -- specify DNS servers for challenge verification
- For large clusters (1000+ certificates): increase controller replicas, tune leader election

### Slide 54 -- mTLS and Zero Trust

- cert-manager + trust-manager = building blocks for mTLS
- Pattern: issue client + server certs from the same CA, distribute CA bundle via trust-manager
- Combine with OpenShift Service Mesh (Istio) for sidecar-based mTLS
- Or application-level mTLS for non-mesh workloads
- Reference: Red Hat Developer article (June 2026)

### Slide 55 -- External Issuer Integrations

| Issuer | Project | Use Case |
|--------|---------|----------|
| AWS PCA | github.com/cert-manager/aws-privateca-issuer | AWS-managed private CA |
| Google CAS | github.com/jetstack/google-cas-issuer | Google Cloud CA Service |
| Vault | Built-in | HashiCorp Vault PKI |
| Venafi | Built-in | Enterprise PKI |
| Smallstep | github.com/smallstep/step-issuer | Zero-trust infrastructure |
| ADCS | github.com/djkormo/adcs-issuer | Microsoft Active Directory CS |

---

## Section 8: Troubleshooting & Wrap-Up (Slides 56-60)

### Slide 56 -- Troubleshooting Decision Tree

- Diagram/flowchart:
  1. Certificate not Ready? --> `oc describe certificate`
  2. Issuer not Ready? --> `oc describe clusterissuer` --> check Secret, permissions
  3. CertificateRequest pending? --> `oc describe certificaterequest` --> check issuer logs
  4. ACME Order failing? --> `oc get orders` --> DNS propagation? HTTP reachable?
  5. Webhook errors? --> check webhook pod running, NetworkPolicy not blocking

### Slide 57 -- Essential Troubleshooting Commands

```bash
oc get certificate -A
oc describe certificate <name> -n <ns>
oc get certificaterequest -A
oc logs -n cert-manager deploy/cert-manager -f
oc get events --field-selector reason=IssueError -n <ns>
```

### Slide 58 -- Key Takeaways

1. cert-manager turns certificate management from toil into automation
2. The two-tier CA pattern (SelfSigned -> CA Issuer) covers most internal use cases
3. ACME integration provides free, trusted certificates from Let's Encrypt
4. openshift-routes controller makes Route TLS one annotation away
5. trust-manager completes the story by distributing CA bundles automatically
6. Everything is declarative, auditable, and GitOps-ready

### Slide 59 -- Next Steps for Attendees

- Evaluate cert-manager in your staging environment
- Identify your certificate inventory (which certs are manually managed today?)
- Choose the right issuer type for your organization
- Contact your Red Hat account team for an architecture review
- Resources:
  - Red Hat Docs
  - cert-manager.io
  - Red Hat Learning: "Simplify Certificate Management on OpenShift"

### Slide 60 -- Thank You & Feedback

- QR code linking to feedback survey
- Presenter contact information
- Link to lab materials repository
- "Thank you for attending!"
