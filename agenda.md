# OpenShift cert-manager Operator -- Full-Day Workshop

## Workshop Details

| Item | Detail |
|------|--------|
| **Title** | Automating Certificate Lifecycle on OpenShift with cert-manager |
| **Duration** | Full day (8 hours, 09:00 -- 17:00) |
| **Level** | Intermediate |
| **Product** | cert-manager Operator for Red Hat OpenShift v1.20.0 on OCP 4.20+ |
| **Audience** | OpenShift cluster admins, platform engineers, DevSecOps teams |

---

## Prerequisites

- Access to an OpenShift 4.20+ cluster with **cluster-admin** privileges (RHPDS sandbox, demo.redhat.com, or self-managed)
- `oc` CLI installed and authenticated (`oc whoami` returns your user)
- A browser open to the OpenShift Web Console
- Basic familiarity with Kubernetes resources (Secrets, Namespaces, Operators)
- A terminal with `openssl` available

---

## Agenda

### Block 1 -- Foundations (09:00 -- 10:30)

| Time | Session | Format | Duration |
|------|---------|--------|----------|
| 09:00 -- 09:20 | **Welcome, Agenda, and Introductions** | Presentation | 20 min |
| | Facilitator introduction, participant round-table, workshop objectives, logistics (Wi-Fi, breaks, lab access). | | |
| 09:20 -- 09:50 | **TLS/PKI Primer -- Why Certificate Automation Matters** | Presentation | 30 min |
| | X.509 basics: CA hierarchies, leaf certs, chains of trust, public/private key pairs. Manual cert management pain points: expiry outages, operational toil, compliance drift. How cert-manager provides Certificates-as-a-Service on Kubernetes. | | |
| 09:50 -- 10:15 | **cert-manager Architecture Deep Dive** | Presentation + Whiteboard | 25 min |
| | Core components: controller, webhook, CA injector. Custom Resource model: Issuer / ClusterIssuer, Certificate, CertificateRequest, Order, Challenge. Reconciliation loop: request --> approve --> issue --> store in Secret --> renew. Red Hat operator vs. upstream community: support boundaries, update channels (`stable-v1`), OLM lifecycle. | | |
| 10:15 -- 10:30 | **Break** | | 15 min |

### Block 2 -- Installation and First Certificate (10:30 -- 12:00)

| Time | Session | Format | Duration |
|------|---------|--------|----------|
| 10:30 -- 11:00 | **Demo 1: Installing the Operator** | Live Demo | 30 min |
| | Install via OperatorHub (Web Console walkthrough). CLI-only install: Namespace, OperatorGroup, Subscription YAML. Verify: operator pod in `cert-manager-operator`, workload pods in `cert-manager` (controller, webhook, cainjector). Explore the `CertManager` CR and customization options (CPU/memory overrides, log levels). | | |
| 11:00 -- 11:45 | **Lab 1: Self-Signed Issuer and Your First Certificate** | Hands-On | 45 min |
| | Create a SelfSigned `ClusterIssuer`. Create a root CA `Certificate` backed by the self-signed issuer. Create a CA `ClusterIssuer` referencing the root CA secret. Issue a leaf `Certificate` for a sample app namespace. Inspect the resulting TLS Secret (`tls.crt`, `tls.key`, `ca.crt`) with `openssl`. | | |
| 11:45 -- 12:00 | **Q&A + Recap** | Discussion | 15 min |

### Block 3 -- Lunch (12:00 -- 13:00)

### Block 4 -- Real-World Issuers (13:00 -- 14:30)

| Time | Session | Format | Duration |
|------|---------|--------|----------|
| 13:00 -- 13:30 | **Issuer Types Overview** | Presentation | 30 min |
| | SelfSigned, CA, ACME (HTTP-01 / DNS-01), Vault, Venafi, External issuers. When to use which: dev/test vs. staging vs. production. ACME protocol explained: account registration, challenges, order lifecycle. | | |
| 13:30 -- 14:00 | **Demo 2: ACME with Let's Encrypt (or IdM)** | Live Demo | 30 min |
| | Create a Let's Encrypt staging `ClusterIssuer` with DNS-01 solver (Cloudflare / Route53 example). Show the `Order` and `Challenge` resources in flight. Certificate issued -- inspect the chain signed by Let's Encrypt staging CA. Discuss rate limits and why to always test with staging first. | | |
| 14:00 -- 14:20 | **Lab 2: Securing an Application with a CA-Issued Certificate** | Hands-On | 20 min |
| | Deploy a sample HTTPD application. Create a `Certificate` resource referencing the CA `ClusterIssuer`. Mount the TLS secret into the pod and expose via a passthrough Route. Verify HTTPS end-to-end with `curl --cacert`. | | |
| 14:20 -- 14:30 | **Break** | | 10 min |

### Block 5 -- Ingress, Routes, and Wildcard Certs (14:30 -- 15:30)

| Time | Session | Format | Duration |
|------|---------|--------|----------|
| 14:30 -- 14:50 | **Securing OpenShift Routes with cert-manager** | Presentation | 20 min |
| | The `openshift-routes` controller: bridging cert-manager and Route objects. Route annotations: `cert-manager.io/issuer-name`, `cert-manager.io/issuer-kind`, duration, renew-before. Replacing the default wildcard ingress certificate with a cert-manager-managed cert. | | |
| 14:50 -- 15:15 | **Demo 3: Auto-TLS on OpenShift Routes** | Live Demo | 25 min |
| | Install the openshift-routes controller (Helm). Annotate a Route -- watch `route.spec.tls` get populated automatically. Replace the default IngressController certificate: create a Certificate in `openshift-ingress`, patch the IngressController `spec.defaultCertificate.name`. Browse the app -- show the valid cert in browser. | | |
| 15:15 -- 15:30 | **Lab 3: Annotate Your Own Route** | Hands-On | 15 min |
| | Attendees annotate a route in their own project and observe automatic certificate issuance and TLS population on the Route. | | |

### Block 6 -- trust-manager and Advanced Topics (15:30 -- 16:30)

| Time | Session | Format | Duration |
|------|---------|--------|----------|
| 15:30 -- 15:50 | **trust-manager: Distributing Trust Bundles (Tech Preview)** | Presentation | 20 min |
| | The problem: every namespace needs the CA bundle -- manual ConfigMap copies don't scale. trust-manager operand: `Bundle` CR, sources (Secret, ConfigMap, useDefaultCAs), targets. Enabling: set `UNSUPPORTED_ADDON_FEATURES=TrustManager=true` on the Subscription (no longer needs TechPreviewNoUpgrade FeatureSet as of v1.19+). | | |
| 15:50 -- 16:10 | **Demo 4: trust-manager in Action** | Live Demo | 20 min |
| | Enable trust-manager on the operator subscription. Create a `Bundle` resource sourcing the internal CA cert. Label target namespaces. Verify: ConfigMap with `bundle.pem` appears in labeled namespaces. Mount the bundle into an app and verify the trust chain. | | |
| 16:10 -- 16:30 | **Advanced Topics** | Presentation + Discussion | 20 min |
| | Certificate renewal tuning (`--certificate-request-minimum-backoff-duration`). CPU/memory overrides via the `CertManager` CR. Egress proxy configuration for air-gapped/disconnected clusters. Monitoring: cert-manager Prometheus metrics, alerting on expiry. mTLS / zero-trust patterns with cert-manager + trust-manager + Service Mesh. External issuer integrations: HashiCorp Vault, Venafi, AWS PCA. | | |

### Block 7 -- Wrap-Up (16:30 -- 17:00)

| Time | Session | Format | Duration |
|------|---------|--------|----------|
| 16:30 -- 16:45 | **Troubleshooting Cookbook** | Presentation | 15 min |
| | `cmctl status certificate` command. Common failure modes: DNS propagation delays, RBAC issues, issuer not ready, webhook timeout. Useful logs: `oc logs -n cert-manager deploy/cert-manager`. Events: `oc get events --field-selector reason=IssueError`. | | |
| 16:45 -- 16:55 | **Key Takeaways and Next Steps** | Presentation | 10 min |
| | Recap of the day. Pointers: Red Hat documentation, upstream cert-manager.io docs, Red Hat Learning paths. Customer engagement: sizing consultation, architecture review offer. | | |
| 16:55 -- 17:00 | **Feedback Survey and Close** | | 5 min |

---

## Time Breakdown Summary

| Activity | Total Time |
|----------|-----------|
| Presentations / Theory | ~3 hours |
| Live Demos (4 demos) | ~1 hour 45 min |
| Hands-On Labs (4 labs) | ~1 hour 35 min |
| Breaks + Lunch | ~1 hour 25 min |
| Q&A / Wrap-up | ~15 min |
| **Total** | **8 hours** |

---

## Materials Provided to Attendees

1. **Lab Guide** -- step-by-step instructions with all YAML manifests, commands, and expected output
2. **YAML Manifest Bundle** -- Git repository / zip of every manifest used in labs and demos
3. **Cheat Sheet** -- 1-page quick reference for `oc`/`cmctl` commands, CR fields, and troubleshooting
4. **Slides Deck** -- PDF of the presentation slides (distributed after the workshop)

---

## Logistics Checklist (for Facilitator)

- [ ] Confirm RHPDS / demo.redhat.com cluster provisioning (1 cluster per attendee or shared multi-tenant)
- [ ] Pre-install the cert-manager operator on the demo cluster to save time (or leave uninstalled for Demo 1)
- [ ] Test all demos end-to-end on the target cluster the day before
- [ ] Prepare DNS API token (Cloudflare / Route53) for the ACME demo
- [ ] Print cheat sheets (or prepare digital copies)
- [ ] Set up a shared chat channel (Slack / Google Chat) for real-time Q&A during labs
- [ ] Prepare feedback survey (Google Forms / Red Hat internal survey tool)
- [ ] Have a backup plan if ACME/DNS demo fails: fall back to self-signed/CA path for all demos
