# Demo 2: ACME with Let's Encrypt -- Presenter Script

## Pre-flight

- Confirm you have a domain with DNS API access (Cloudflare, Route53, etc.)
- Have the API token ready
- Have a terminal with `oc` logged in as cluster-admin

## Live Demo Steps

### 1. Show the problem (30 seconds)

> "Let's Encrypt is the world's most popular public CA. It issues free, trusted
> certificates using the ACME protocol. cert-manager has native ACME support,
> so we can automate the entire flow."

### 2. Create the DNS API token secret (1 minute)

```bash
# Show the YAML (redact the actual token on screen)
cat 00-secret-dns-api-token.yaml

# Apply it
oc apply -f 00-secret-dns-api-token.yaml
```

### 3. Create the staging ClusterIssuer (2 minutes)

> "We always start with staging to avoid rate limits."

```bash
cat 01-clusterissuer-letsencrypt-staging.yaml
oc apply -f 01-clusterissuer-letsencrypt-staging.yaml

# Check it's ready
oc get clusterissuer letsencrypt-staging
oc describe clusterissuer letsencrypt-staging
```

> Point out the `Registered` condition -- cert-manager created an ACME account.

### 4. Request a certificate (5 minutes)

```bash
cat 03-certificate-acme.yaml
oc apply -f 03-certificate-acme.yaml
```

> "Now watch the ACME flow in real time:"

```bash
# In a split terminal, watch these simultaneously:
oc get certificate acme-demo-cert -n default -w
oc get orders.acme.cert-manager.io -n default -w
oc get challenges.acme.cert-manager.io -n default -w
```

> Walk through what's happening:
> 1. cert-manager creates a CertificateRequest
> 2. The ACME issuer creates an Order
> 3. The Order creates Challenge(s) -- one per domain
> 4. cert-manager creates a TXT record via the DNS API
> 5. Let's Encrypt verifies the TXT record
> 6. Certificate is issued and stored in the Secret

### 5. Inspect the certificate (2 minutes)

```bash
oc get secret acme-demo-tls -n default \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

> Point out:
> - Issuer: "(STAGING) Artificial Apricot R11" (Let's Encrypt staging CA)
> - SANs include both the base domain and the wildcard
> - Validity: 90 days

### 6. Staging vs Production (1 minute)

> "Once staging works, switching to production is a one-line change:
> just reference the `letsencrypt-prod` ClusterIssuer instead."
>
> Show `02-clusterissuer-letsencrypt-prod.yaml` for reference.

## Fallback Plan

If DNS API access is unavailable or flaky during the live demo:

1. Skip the ACME demo.
2. Show the YAML files and explain the flow using the whiteboard/slides.
3. Use the CA issuer from Lab 1 for all remaining demos.
4. Mention: "In your own environment, you would replace `ca-issuer` with `letsencrypt-prod`."
