# Managed Kubernetes Deployment (DigitalOcean)

This document outlines the transition from a local `kind` cluster to a production-ready managed Kubernetes environment. While targeted at DigitalOcean, the patterns and practices are portable to other managed Kubernetes services (AWS EKS, GCP GKE, Azure AKS).

> Current status (Nov 2025): Local development uses `kind` with a self-hosted PostgreSQL chart. This guide covers moving to DigitalOcean Managed Kubernetes + Managed PostgreSQL.

## 1. Architecture Overview

### Local Setup (Current)
```
Developer Machine
  └─ kind cluster
      ├─ api deployment
      ├─ web deployment
      ├─ admin deployment
      └─ postgres (self-hosted)
```

### Managed Setup (Target)
```
DigitalOcean Account
  ├─ DKE Cluster (Kubernetes)
  │   ├─ api deployment
  │   ├─ web deployment
  │   ├─ admin deployment
  │   ├─ nginx ingress controller
  │   └─ sealed-secrets controller
  ├─ DO Managed PostgreSQL (external DB)
  ├─ DOCR (Container Registry)
  ├─ DO Load Balancer (provisioned by Ingress)
  └─ DO DNS
```

Key changes:
- **Database**: Self-hosted `postgres` chart → DigitalOcean Managed PostgreSQL
- **Registry**: Local Docker images → DigitalOcean Container Registry (DOCR)
- **Secrets**: Manual `.env` files → Sealed Secrets (encrypted in git)
- **CI/CD**: Manual deployment → GitHub Actions (build, push, deploy)
- **Ingress**: Local testing → NGINX Ingress Controller + DO Load Balancer

## 2. Infrastructure Setup

### 2.1 Prerequisites
- DigitalOcean account with billing enabled
- `doctl` CLI installed and authenticated
- `kubectl` configured
- `helm` 3.x installed
- `kubeseal` CLI (for Sealed Secrets)

### 2.2 Create DigitalOcean Kubernetes Cluster

```bash
# Create a managed Kubernetes cluster (3 nodes, appropriate sizing)
doctl kubernetes cluster create yab-prod \
  --region nyc3 \
  --version latest \
  --node-pool="name=worker-pool;size=s-2vcpu-4gb;count=3;auto-scale=true;min-nodes=3;max-nodes=10"

# Save kubeconfig
doctl kubernetes cluster kubeconfig save yab-prod

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### 2.3 Create DigitalOcean Managed PostgreSQL

```bash
# Create a managed PostgreSQL database
doctl databases create --engine pg --region nyc3 --num-nodes 1 yab-postgres

# Get connection details
doctl databases get yab-postgres --format Name,Host,Port,User,db_name --no-header

# Save connection string (you'll use this for secrets)
# Format: postgresql://user:password@host:port/dbname
```

Store the connection string securely; you'll encrypt it with Sealed Secrets later.

### 2.4 Create DigitalOcean Container Registry

```bash
# Create a container registry
doctl registry create yab-registry --region nyc3

# Configure Docker authentication
doctl registry login

# Verify you can push images
docker tag myapp:latest registry.digitalocean.com/yab-registry/myapp:latest
docker push registry.digitalocean.com/yab-registry/myapp:latest
```

## 3. Cluster Configuration

### 3.1 Install NGINX Ingress Controller

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install ingress controller (DigitalOcean will provision a Load Balancer automatically)
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.metrics.enabled=true

# Wait for the Load Balancer IP to be assigned
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -w

# Note: Once the IP is assigned, point your DNS A record to this IP
```

### 3.2 Install Sealed Secrets Controller

```bash
# Add Helm repo
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

# Install sealed-secrets controller
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --version 2.13.2

# Verify installation
kubectl get pods -n kube-system | grep sealed-secrets
```

## 4. Helm Chart Refactoring

### 4.1 Parameterize Database Host

The API deployment's `wait-for-db` init container currently hardcodes `postgres:5432`. Update `charts/api/values.yaml`:

```yaml
# charts/api/values.yaml
database:
  host: "postgres"  # Override in production
  port: 5432
  name: "boilerplate"
  user: "postgres"

# Example production override in kustomization.yaml:
# helm values:
#   - database.host: "yab-postgres-xxxxx-do-user-1234567-0.b.db.ondigitalocean.com"
#     database.port: 25060
#     database.name: "defaultdb"
#     database.user: "doadmin"
```

Update `charts/api/templates/deployment.yaml` to use these values:

```yaml
initContainers:
  - name: wait-for-db
    image: postgres:15-alpine
    imagePullPolicy: IfNotPresent
    command:
      - sh
      - -c
      - >-
        echo "[wait-for-db] Waiting for Postgres at {{ .Values.database.host }}:{{ .Values.database.port }}";
        for i in $(seq 1 60); do
          pg_isready -h {{ .Values.database.host }} -p {{ .Values.database.port }} -U {{ .Values.database.user }} >/dev/null 2>&1 && echo "[wait-for-db] Postgres is ready" && exit 0;
          echo "[wait-for-db] Attempt $i/60: Postgres not ready yet";
          sleep 2;
        done;
        echo "[wait-for-db] Timed out waiting for Postgres";
        exit 1;
```

### 4.2 Disable Self-Hosted PostgreSQL in Production

In `k8s/overlays/production/kustomization.yaml`, disable the postgres chart:

```yaml
# k8s/overlays/production/kustomization.yaml
helmCharts:
  - name: postgres
    repo: ../../charts/postgres
    # Comment out or remove this chart entirely for production
    # enabled: false (not standard Helm syntax in kustomization)
    # Instead, use namespace replacements or overlays to skip it

# Simpler approach: only include api, web, admin charts
```

Or create a separate `production-no-db` chart dependency that doesn't include postgres.

## 5. Secrets Management

### 5.1 Create Production Secrets

Create a `secrets.env` file (never commit this):

```bash
# k8s/overlays/production/secrets.env
DATABASE_URL=postgresql://doadmin:YOUR_PASSWORD@yab-postgres-xxxxx-do-user-1234567-0.b.db.ondigitalocean.com:25060/defaultdb
SECRET_KEY=your-django-secret-key
DEBUG=False
ALLOWED_HOSTS=example.com,www.example.com
```

### 5.2 Encrypt with Sealed Secrets

```bash
# Create a Kubernetes secret from the env file
kubectl create secret generic api-secrets \
  --from-env-file=k8s/overlays/production/secrets.env \
  --dry-run=client \
  -o yaml > api-secrets.yaml

# Seal the secret (requires sealed-secrets controller running)
kubeseal -f api-secrets.yaml -w sealed-api-secrets.yaml

# Verify the sealed secret is encrypted
cat sealed-api-secrets.yaml

# Commit the sealed version to git (safe to commit)
mv sealed-api-secrets.yaml k8s/overlays/production/sealed-api-secrets.yaml
git add k8s/overlays/production/sealed-api-secrets.yaml
git rm k8s/overlays/production/secrets.yaml  # Remove unencrypted
```

### 5.3 Reference Sealed Secrets in Kustomization

```yaml
# k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
  - ../../base/namespaces.yaml
  - sealed-api-secrets.yaml  # Your sealed secret

patches:
  - target:
      kind: Deployment
      name: api
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/envFrom
        value:
          - secretRef:
              name: api-secrets  # Sealed Secrets decrypts this automatically

helmCharts:
  - name: api
    repo: ../../charts/api
    version: "1.0.0"
    releaseName: api
    values:
      image:
        tag: "production-v1.0.0"  # Use git tag or commit SHA
```

## 6. CI/CD Pipeline

### 6.1 GitHub Actions Workflow

Create `.github/workflows/deploy-production.yml`:

```yaml
name: Build and Deploy to Production

on:
  push:
    branches:
      - main
    tags:
      - 'v*'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [api, web, admin]

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Authenticate with DOCR
        uses: docker/login-action@v2
        with:
          registry: registry.digitalocean.com
          username: ${{ secrets.DOCR_USERNAME }}
          password: ${{ secrets.DOCR_PASSWORD }}

      - name: Build and push ${{ matrix.service }}
        uses: docker/build-push-action@v4
        with:
          context: ./packages/${{ matrix.service }}
          push: true
          tags: |
            registry.digitalocean.com/yab-registry/${{ matrix.service }}:latest
            registry.digitalocean.com/yab-registry/${{ matrix.service }}:${{ github.sha }}
            registry.digitalocean.com/yab-registry/${{ matrix.service }}:${{ github.ref_name }}
          cache-from: type=registry,ref=registry.digitalocean.com/yab-registry/${{ matrix.service }}:latest
          cache-to: type=inline

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref_type == 'tag'  # Deploy only on tags

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: latest

      - name: Set kubeconfig
        run: |
          echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > /tmp/kubeconfig
          export KUBECONFIG=/tmp/kubeconfig

      - name: Update image tags in kustomization
        run: |
          cd k8s/overlays/production
          kustomize edit set image \
            api=registry.digitalocean.com/yab-registry/api:${{ github.sha }} \
            web=registry.digitalocean.com/yab-registry/web:${{ github.sha }} \
            admin=registry.digitalocean.com/yab-registry/admin:${{ github.sha }}

      - name: Apply kustomization
        run: |
          export KUBECONFIG=/tmp/kubeconfig
          kubectl apply -k k8s/overlays/production

      - name: Wait for rollout
        run: |
          export KUBECONFIG=/tmp/kubeconfig
          kubectl rollout status deployment/api -n production --timeout=5m
          kubectl rollout status deployment/web -n production --timeout=5m
          kubectl rollout status deployment/admin -n production --timeout=5m
```

### 6.2 GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

- `DOCR_USERNAME`: DigitalOcean API token (for registry push)
- `DOCR_PASSWORD`: DigitalOcean API token (for registry push)
- `KUBE_CONFIG`: Base64-encoded kubeconfig for your DO cluster (get with `doctl kubernetes cluster kubeconfig save yab-prod --format=json | jq -r '.clusters[0].config' | base64`)

## 7. Production Overlay Configuration

### 7.1 Update Production Overlay

```yaml
# k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

bases:
  - ../../base

resources:
  - sealed-api-secrets.yaml
  - cert-issuer-prod.yaml  # Existing production cert issuer

helmCharts:
  - name: api
    repo: ../../charts/api
    version: "1.0.0"
    releaseName: api
    values:
      replicaCount: 3
      image:
        repository: registry.digitalocean.com/yab-registry/api
        tag: latest
      database:
        host: "yab-postgres-xxxxx-do-user-1234567-0.b.db.ondigitalocean.com"
        port: 25060
        name: "defaultdb"
        user: "doadmin"
      resources:
        requests:
          memory: "512Mi"
          cpu: "250m"
        limits:
          memory: "1Gi"
          cpu: "500m"

  - name: web
    repo: ../../charts/web
    version: "1.0.0"
    releaseName: web
    values:
      replicaCount: 2
      image:
        repository: registry.digitalocean.com/yab-registry/web
        tag: latest

  - name: admin
    repo: ../../charts/admin
    version: "1.0.0"
    releaseName: admin
    values:
      replicaCount: 1
      image:
        repository: registry.digitalocean.com/yab-registry/admin
        tag: latest

patchesJson6902:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: api
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/env
        value:
          - name: DATABASE_URL
            valueFrom:
              secretKeyRef:
                name: api-secrets
                key: DATABASE_URL
          - name: DEBUG
            value: "False"

# Remove the local postgres chart
helmCharts:
  # Omit or don't include the postgres chart
```

### 7.2 Update Ingress for Production

```yaml
# k8s/overlays/production/ingress-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - example.com
        - www.example.com
        - admin.example.com
      secretName: tls-main-cert
  rules:
    - host: example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 8000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
    - host: admin.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: admin
                port:
                  number: 80
```

## 8. Deployment Steps

### 8.1 First-Time Setup

```bash
# 1. Provision infrastructure (Section 2)
doctl kubernetes cluster create yab-prod ...
doctl databases create ...
doctl registry create ...

# 2. Configure cluster (Section 3)
helm install nginx-ingress ...
helm install sealed-secrets ...

# 3. Refactor Helm charts (Section 4)
# Update charts/api/values.yaml and templates/deployment.yaml
# Commit changes to git

# 4. Create and seal secrets (Section 5)
kubectl create secret generic api-secrets --from-env-file=...
kubeseal -f api-secrets.yaml -w sealed-api-secrets.yaml
git add k8s/overlays/production/sealed-api-secrets.yaml

# 5. Deploy for the first time
kubectl apply -k k8s/overlays/production

# 6. Verify deployments
kubectl get pods -n production
kubectl get svc -n production
kubectl get ingress -n production
```

### 8.2 Continuous Deployment

Once CI/CD is configured:

```bash
# Tag a release
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# GitHub Actions automatically:
# 1. Builds Docker images for api, web, admin
# 2. Pushes to DOCR
# 3. Updates kustomization image tags
# 4. Applies to production cluster
# 5. Waits for rollout to complete

# Monitor deployment
kubectl rollout status deployment/api -n production
kubectl logs -n production -f deployment/api
```

## 9. DNS and SSL/TLS

### 9.1 Point Domain to Load Balancer

```bash
# Get the Load Balancer IP assigned by NGINX Ingress Controller
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller

# Example output:
# NAME                                              TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# nginx-ingress-ingress-nginx-controller            LoadBalancer   10.245.x.x     192.0.2.100      80:30123/TCP,443:30456/TCP

# In your DNS provider (or DigitalOcean DNS):
# example.com  A  192.0.2.100
# *.example.com  A  192.0.2.100
```

### 9.2 Configure Let's Encrypt (Existing cert-manager Setup)

Your existing `cert-manager` + `ClusterIssuer` setup in `k8s/base/cert-issuers/letsencrypt-prod-issuer.yaml` will automatically provision SSL certificates for all Ingress resources annotated with `cert-manager.io/cluster-issuer: letsencrypt-prod`.

```bash
# Monitor certificate provisioning
kubectl describe certificate tls-main-cert -n production

# Once ready:
kubectl get certificate -n production
# tls-main-cert          True          secret-name          v1        7d
```

## 10. Monitoring and Maintenance

### 10.1 Health Checks

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -n production
kubectl get svc -n production

# Check database connectivity from pods
kubectl exec -it deployment/api -n production -- sh
$ psql -h <DB_HOST> -U doadmin -d defaultdb
```

### 10.2 Logs and Troubleshooting

```bash
# View pod logs
kubectl logs deployment/api -n production
kubectl logs deployment/api -n production --tail=100 -f

# Describe pod for events
kubectl describe pod <POD_NAME> -n production

# Check sealed-secrets status
kubectl get sealedsecrets -n production
kubectl describe sealedsecret api-secrets -n production
```

### 10.3 Backup and Recovery

```bash
# Backup Sealed Secrets sealing key (critical!)
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
# Store this securely (encrypted, offline)

# Backup managed database
doctl databases backup create yab-postgres

# List backups
doctl databases backup list yab-postgres
```

## 11. Cost Estimation (DigitalOcean)

| Component                        | Cost (Monthly) | Notes                                   |
| :------------------------------- | :------------- | :-------------------------------------- |
| **DKE Cluster** (3x s-2vcpu-4gb) | ~$60           | Auto-scaling: +$20 per node added       |
| **Managed PostgreSQL** (s-1vcpu) | ~$15           | Upgrade to s-2vcpu-4gb for HA: ~$30     |
| **Container Registry**           | ~$5            | $0.20 per GB stored                     |
| **Load Balancer**                | ~$12           | Provisioned automatically by Ingress    |
| **Storage** (if using PVCs)      | ~$0.10/GB      | Optional; not needed for stateless apps |
| **Total (Minimum)**              | ~$92/month     | Scale costs increase with traffic       |

## 12. Migration Checklist

- [ ] Create DigitalOcean account and enable billing
- [ ] Provision DKE cluster, Managed PostgreSQL, Container Registry
- [ ] Install NGINX Ingress Controller
- [ ] Install Sealed Secrets controller
- [ ] Refactor Helm charts to accept external DB parameters
- [ ] Create and encrypt production secrets with kubeseal
- [ ] Update `k8s/overlays/production` configuration
- [ ] Set up GitHub Actions workflow for CI/CD
- [ ] Add DOCR and kubeconfig secrets to GitHub
- [ ] Deploy production overlay to the managed cluster
- [ ] Configure DNS A records to point to Load Balancer IP
- [ ] Verify Let's Encrypt certificates are provisioned
- [ ] Test deployments and rollbacks
- [ ] Back up Sealed Secrets sealing key
- [ ] Document team access patterns (kubectl, logs, debugging)

## 13. References

- [DigitalOcean Kubernetes Documentation](https://docs.digitalocean.com/products/kubernetes/)
- [DigitalOcean Managed Databases](https://docs.digitalocean.com/products/databases/)
- [DigitalOcean Container Registry](https://docs.digitalocean.com/products/container-registry/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)

---

This document should be updated as the deployment matures (e.g., auto-scaling policies, backup strategies, multi-region setup). Reference this guide from `Docs/01-main.md`.
