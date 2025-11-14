# TLS & Certificate Management Setup

## Overview

This directory contains Kubernetes Certificate Issuers for managing TLS certificates across environments.

- **Local**: Self-signed certificates (no external validation)
- **Staging**: Let's Encrypt staging (free, but untrusted by browsers — for testing)
- **Production**: Let's Encrypt production (trusted, automatic renewal)

## Prerequisites

Install cert-manager to the cluster first:

```bash
# Add cert-manager Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

## Local Setup (Self-Signed)

For local development, use self-signed certificates (no Let's Encrypt validation):

```bash
kubectl apply -f k8s/base/cert-issuers/local-selfsigned-issuer.yaml
```

Then enable TLS in your Ingress:

```bash
helm upgrade yab-api charts/api \
  --namespace apps \
  --set ingress.enabled=true \
  --set ingress.tls[0].secretName=api-tls \
  --set ingress.tls[0].hosts[0]=api.local.dev \
  --set ingress.annotations."cert-manager\\.io/cluster-issuer"=local-selfsigned
```

Access: `https://api.local.dev` (browser will warn about untrusted certificate — expected for self-signed).

## Staging Setup (Let's Encrypt Staging)

For pre-production testing with real-ish certificates:

```bash
kubectl apply -f k8s/base/cert-issuers/letsencrypt-staging-issuer.yaml
```

Update Ingress:

```bash
helm upgrade yab-api charts/api \
  --namespace apps \
  --set ingress.enabled=true \
  --set ingress.tls[0].secretName=api-tls \
  --set ingress.tls[0].hosts[0]=api.staging.example.com \
  --set ingress.annotations."cert-manager\\.io/cluster-issuer"=letsencrypt-staging
```

**Note**: Requires valid DNS pointing to your staging cluster.

## Production Setup (Let's Encrypt Production)

For live traffic with trusted certificates:

```bash
kubectl apply -f k8s/base/cert-issuers/letsencrypt-prod-issuer.yaml
```

Update Ingress:

```bash
helm upgrade yab-api charts/api \
  --namespace apps \
  --set ingress.enabled=true \
  --set ingress.tls[0].secretName=api-tls \
  --set ingress.tls[0].hosts[0]=api.example.com \
  --set ingress.annotations."cert-manager\\.io/cluster-issuer"=letsencrypt-prod
```

**Important**:
- Requires valid DNS and email for Let's Encrypt (set in issuer manifest)
- Rate limits apply (50 certificates per domain per week)
- Certificates auto-renew 30 days before expiry

## Monitoring Certificate Status

```bash
# Check Certificate resources
kubectl get certificate -n apps

# Check Certificate details
kubectl describe certificate api-tls -n apps

# Check issuer status
kubectl describe clusterissuer letsencrypt-prod

# View cert-manager logs for debugging
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

## Troubleshooting

**Certificate stuck in "Pending"**:
- Check DNS resolution (especially for Let's Encrypt)
- Check cert-manager logs: `kubectl logs -n cert-manager ...`
- Verify ClusterIssuer email/API tokens (for Let's Encrypt)

**"ACME order failed"**:
- Likely DNS issue or rate limit hit
- Wait 1 hour before retrying (rate limit backoff)
- Check Let's Encrypt [documentation](https://letsencrypt.org/docs/)

**Self-signed certificate warnings in browser**:
- Expected for local development
- Add exception or use `curl -k` to bypass
