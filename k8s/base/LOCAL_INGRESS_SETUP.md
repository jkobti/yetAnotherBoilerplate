# Local Ingress Setup Guide (kind + NGINX + api.local.dev)

## ⚠️ Known Limitation

**kind on Docker Desktop (Mac/Windows) does not support LoadBalancer/Ingress port forwarding to the host.**

For local development on Mac/Windows with kind, use **kubectl port-forward** instead (see below).

For production-like ingress testing, deploy to a cloud cluster (GKE, EKS) or use a different local setup (Minikube with virtual machine backend, or Docker with proper networking).

## Recommended Local Setup (Simple & Working)

Use `kubectl port-forward` for local development:

```bash
# Terminal 1: Forward API service
kubectl port-forward -n apps svc/api-api 8000:8000

# Terminal 2: Access API
curl http://localhost:8000/health/
```

This avoids ingress complexity and works reliably on Mac/Windows.

---

## Full Ingress Setup (For Reference / Cloud Deployment)

The following steps set up ingress that **will work on cloud clusters** but have limitations locally with kind on Docker Desktop.

### Step 1: DNS Configuration (Local)

Add `api.local.dev` to your `/etc/hosts` file:

```bash
make setup-local-dns
```

### Step 2: Install NGINX Ingress Controller

```bash
make install-nginx
```

### Step 3: Enable Ingress on API Chart

```bash
make deploy-ingress
```

### Step 4: Local Testing via Port-Forward

Since kind on Docker Desktop doesn't expose ingress properly, use port-forward as a proxy:

```bash
# Get the NGINX controller NodePort
kubectl get svc -n ingress

# Port-forward to the NGINX service
kubectl port-forward -n ingress svc/nginx-ingress-ingress-nginx-controller 8080:80

# In another terminal, test
curl -H "Host: api.local.dev" http://localhost:8080/health/
```

Or skip ingress locally and just use direct service port-forward (simpler).

---

## Troubleshooting

### "Connection refused" on api.local.dev

**Expected on Mac/Windows with kind on Docker Desktop.** Use `kubectl port-forward` instead.

### For Cloud Deployment (GKE/EKS/etc.)

Ingress works out-of-the-box on cloud clusters:

1. **Enable Ingress**:
   ```bash
   helm upgrade yab-api charts/api -n apps \
     --set ingress.enabled=true \
     --set ingress.hosts[0].host=api.example.com \
     --set ingress.className=nginx  # or appropriate class for your cloud
   ```

2. **Install NGINX controller** (cloud-specific, usually via cloud provider):
   ```bash
   # For GKE
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.0/deploy/static/provider/cloud/deploy.yaml
   ```

3. **Point DNS** to the LoadBalancer IP:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   # Use the EXTERNAL-IP in your DNS provider
   ```

4. **Enable TLS** with cert-manager (see `k8s/base/cert-issuers/README.md`):
   ```bash
   helm upgrade yab-api charts/api -n apps \
     --set ingress.enabled=true \
     --set 'ingress.tls[0].secretName=api-tls' \
     --set 'ingress.tls[0].hosts[0]=api.example.com' \
     --set 'ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod'
   ```

---

## Summary

- **Local dev (Mac/Windows kind)**: Use `kubectl port-forward` (simple, working)
- **Local dev (Linux / Minikube VM)**: Ingress works natively
- **Cloud (GKE/EKS/etc.)**: Ingress works; LoadBalancer gets real IP
- **Production**: Ingress + cert-manager + Let's Encrypt (fully automated TLS)
