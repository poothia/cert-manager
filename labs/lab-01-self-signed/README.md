# Lab 1: Self-Signed Issuer and Your First Certificate

## Objective

Build a two-tier internal PKI: a self-signed root CA and a CA issuer that signs leaf certificates.

## Steps

### Step 1 -- Create the SelfSigned ClusterIssuer

```bash
oc apply -f 00-clusterissuer-selfsigned.yaml
oc get clusterissuer selfsigned-issuer
```

**Expected**: STATUS = `True` (Ready).

### Step 2 -- Create the Root CA Certificate

```bash
oc apply -f 01-certificate-root-ca.yaml
oc get certificate root-ca -n cert-manager
```

**Expected**: READY = `True`. A Secret `root-ca-secret` appears in the `cert-manager` namespace.

**Verify** the CA certificate:

```bash
oc get secret root-ca-secret -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

Look for:
- `Issuer` = `Subject` = `CN = Workshop Root CA`
- `CA:TRUE` in Basic Constraints

### Step 3 -- Create the CA ClusterIssuer

```bash
oc apply -f 02-clusterissuer-ca.yaml
oc get clusterissuer ca-issuer
```

**Expected**: STATUS = `True` (Ready).

### Step 4 -- Issue a Leaf Certificate

Edit `03-certificate-leaf.yaml` and replace the `dnsNames` value with a hostname matching your cluster's apps domain.

```bash
oc apply -f 03-certificate-leaf.yaml
oc get certificate my-app-cert -n default
```

**Expected**: READY = `True`. A Secret `my-app-tls` appears in the `default` namespace.

**Verify** the leaf certificate:

```bash
oc get secret my-app-tls -n default \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

Look for:
- `Issuer` = `CN = Workshop Root CA`
- `Subject Alternative Name` includes your DNS name
- `CA:FALSE` (this is a leaf cert, not a CA)

## Cleanup

```bash
oc delete certificate my-app-cert -n default
oc delete secret my-app-tls -n default
# Keep the root CA and issuers -- they are used in subsequent labs.
```
