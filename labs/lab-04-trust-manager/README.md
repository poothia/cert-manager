# Lab 4 (Bonus): trust-manager -- Distributing Trust Bundles

## Objective

Enable the trust-manager operand (Technology Preview) and use a `Bundle` resource to automatically distribute your internal CA certificate to application namespaces.

## Prerequisites

- Lab 1 completed (root-ca-secret exists in the cert-manager namespace)
- cert-manager operator v1.19+ installed

## Steps

### Step 1 -- Enable trust-manager

```bash
chmod +x 00-subscription-patch.sh
./00-subscription-patch.sh
```

Or run manually:

```bash
oc -n cert-manager-operator patch subscription openshift-cert-manager-operator \
  --type merge \
  -p '{"spec":{"config":{"env":[{"name":"UNSUPPORTED_ADDON_FEATURES","value":"TrustManager=true"}]}}}'

# Wait for the trust-manager pod
oc get pods -n cert-manager -w
```

**Expected**: A `trust-manager-*` pod appears in the `cert-manager` namespace in Running state.

### Step 2 -- Create the Bundle

```bash
oc apply -f 01-bundle.yaml
oc get bundles.trust.cert-manager.io workshop-ca-bundle
```

### Step 3 -- Label a namespace to receive the bundle

```bash
oc label namespace workshop-demo trust.cert-manager.io/inject=true
```

### Step 4 -- Verify the ConfigMap was distributed

```bash
oc get configmap workshop-ca-bundle -n workshop-demo

# Inspect the contents
oc get configmap workshop-ca-bundle -n workshop-demo \
  -o jsonpath='{.data.ca-bundle\.crt}'
```

**Expected**: The ConfigMap contains the PEM-encoded CA certificate from root-ca-secret.

### Step 5 -- Mount the bundle in an application (optional)

You can mount this ConfigMap into any pod that needs to trust your internal CA:

```yaml
volumes:
  - name: ca-bundle
    configMap:
      name: workshop-ca-bundle
containers:
  - name: my-app
    volumeMounts:
      - name: ca-bundle
        mountPath: /etc/pki/tls/certs/ca-bundle.crt
        subPath: ca-bundle.crt
        readOnly: true
```

### How it works

1. trust-manager watches the `Bundle` resource.
2. It reads the CA cert from the source (the `root-ca-secret` Secret).
3. It creates/updates a ConfigMap named `workshop-ca-bundle` in every namespace matching the label selector.
4. When the CA cert rotates (cert-manager renews it), trust-manager automatically updates all ConfigMaps.

This eliminates the manual toil of copying CA bundles to every namespace.

## Cleanup

```bash
oc delete bundle workshop-ca-bundle
oc label namespace workshop-demo trust.cert-manager.io/inject-
```
