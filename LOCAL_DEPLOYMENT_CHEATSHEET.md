# Local Kubernetes Deployment Cheatsheet

Quick reference for spinning up the entire local development environment.

## Full Deployment (Copy & Paste)
```bash
make cluster-delete
```


```bash
make kind-up
make build-api build-web build-admin
make load-images
make deploy-local deploy-web deploy-admin
make install-nginx
make create-secrets
```

Or as a one-liner:
```bash
make kind-up && make build-api build-web build-admin && make load-images && make deploy-local deploy-web deploy-admin && make install-nginx && make create-secrets
```

## Step-by-Step Breakdown

| Step | Command                                     | What It Does                                   | Time  |
| ---- | ------------------------------------------- | ---------------------------------------------- | ----- |
| 1    | `make kind-up`                              | Creates local Kubernetes cluster (`yab-local`) | ~30s  |
| 2    | `make build-api build-web build-admin`      | Builds Docker images for all services          | ~3-5m |
| 3    | `make load-images`                          | Loads images into kind cluster                 | ~30s  |
| 4    | `make deploy-local deploy-web deploy-admin` | Deploys services + PostgreSQL to cluster       | ~2m   |
| 5    | `make install-nginx`                        | Installs NGINX ingress controller              | ~1m   |
| 6    | `make create-secrets`                       | Creates Kubernetes secrets from `.env.k8s`     | ~10s  |
| 7    | **Port-forward all services** (see below)   | Make services accessible from localhost        | ~5s   |

**Total time: ~7-10 minutes** (deployment) + 5s (port-forwarding setup)

## Prerequisites

Before running these commands:

1. **Copy the environment file:**
   ```bash
   cp packages/backend/.env.k8s.example packages/backend/.env.k8s
   ```

2. **Edit the environment file** with your local values:
   ```bash
   vim packages/backend/.env.k8s
   ```
   Key variables to check:
   - `DEBUG=true`
   - `SECRET_KEY=dev-secret-key`
   - `DATABASE_URL=postgresql://postgres:postgres@postgres:5432/backend`
   - `ALLOWED_HOSTS=127.0.0.1,localhost,0.0.0.0,api.local.dev`

3. **Verify you have required tools:**
   ```bash
   docker --version
   helm version
   kubectl version --client
   kind version
   ```

## Common Issues & Solutions

### Issue: Pods stuck in `Pending` or `Init:0/1`

**Symptom:** API/web/admin pods won't start
```bash
kubectl get pods -n apps
# api-api-xxxxx   0/1   Init:0/1   0   2m
```

**Solution:** Create the Kubernetes secrets
```bash
make create-secrets
```

The API pod needs the `api-env` secret to run Django migrations in its init container.

### Issue: `ErrImageNeverPull`

**Symptom:** Pods fail with `ErrImageNeverPull` error

**Solution:** Load Docker images into kind
```bash
make load-images
```

This happened if you built images before running `make kind-up`. The cluster can't access your local Docker images without loading them explicitly.

### Issue: PostgreSQL pod not ready

**Symptom:** Deployment fails because Postgres isn't running
```bash
kubectl describe pod -n apps postgres-0
```

**Solution:** Wait a bit longer or check the logs
```bash
kubectl logs -n apps postgres-0
```

PostgreSQL takes ~30-60s to initialize the first time.

### Issue: Service account not found

**Symptom:** Error like `error looking up service account apps/api`

**Solution:** This is now handled automatically, but if it happens:
```bash
kubectl apply -f k8s/base/serviceaccounts.yaml
```

Then restart the deployments:
```bash
kubectl rollout restart deployment -n apps
```

## Accessing Services

### ⚠️ Required: Start Port-Forwarding

**All three services (API, Web, Admin) require port-forwarding to be accessible from your machine.**

**Option 1: Background (no terminal needed)**
```bash
nohup kubectl port-forward -n apps svc/api-api 8000:8000 &
nohup kubectl port-forward -n apps svc/web-web 8080:80 &
nohup kubectl port-forward -n apps svc/admin-admin 8081:80 &
```

This runs the port-forwards in the background and they'll stay active even after you close the terminal.

**Option 2: Keep terminal open**
```bash
kubectl port-forward -n apps svc/api-api 8000:8000 &
kubectl port-forward -n apps svc/web-web 8080:80 &
kubectl port-forward -n apps svc/admin-admin 8081:80 &
```

Or as a single one-liner:
```bash
kubectl port-forward -n apps svc/api-api 8000:8000 & kubectl port-forward -n apps svc/web-web 8080:80 & kubectl port-forward -n apps svc/admin-admin 8081:80 &
```

Keep the terminal open while developing. These port-forwards are lightweight and won't consume significant resources.

### Access URLs

After starting the port-forwards above:

- **API**: http://localhost:8000/health/ (or any API endpoint)
- **Web**: http://localhost:8080
- **Admin**: http://localhost:8081

**Quick test:**
```bash
curl http://localhost:8000/health/
```

## Cleanup & Reset

### Delete entire cluster
```bash
make cluster-delete
```

This removes:
- kind cluster
- Docker images
- kubeconfig context
- local SQLite database

### Just delete the cluster (keep images)
```bash
make kind-down
```

### Restart specific services
```bash
kubectl rollout restart deployment -n apps api-api
kubectl rollout restart deployment -n apps web-web
kubectl rollout restart deployment -n apps admin-admin
```

## Useful Commands

```bash
# Check pod status
kubectl get pods -n apps

# View pod logs
kubectl logs -n apps api-api-xxxxx
kubectl logs -n apps -f api-api-xxxxx   # follow logs

# Check secrets exist
kubectl get secrets -n apps

# View secret values (base64 encoded)
kubectl get secret api-env -n apps -o jsonpath='{.data}'

# Check resource usage
kubectl top pods -n apps

# Describe a pod (shows events and errors)
kubectl describe pod -n apps api-api-xxxxx

# Get all resources in apps namespace
kubectl get all -n apps

# Get helm releases
helm list -n apps
```

## Tips & Tricks

- **Run commands from project root**, not subdirectories. Makefile is in the root.
- **Secrets must be created before or immediately after deployment**. Without them, API pod can't run migrations.
- **Use `kubectl get events -n apps`** to see what's happening if things fail
- **Check pod logs early**: `kubectl logs -n apps <pod-name>` usually tells you what's wrong
- **Port-forward is more reliable than ingress** on Mac/Windows with kind + Docker Desktop
- **Keep port-forward terminals open** while developing—they're lightweight
- **Rebuild an image** with `make build-api` then run `make load-images` to use the new version

## First Time Setup Flow

```bash
# 1. Navigate to project root
cd /Users/joseph/Documents/projects/boiler

# 2. Set up environment file
cp packages/backend/.env.k8s.example packages/backend/.env.k8s
# Edit .env.k8s with your values

# 3. Deploy everything
make kind-up
make build-api build-web build-admin
make load-images
make deploy-local deploy-web deploy-admin
make install-nginx
make create-secrets

# 4. Wait ~30s for pods to stabilize
sleep 30

# 5. Check status
kubectl get pods -n apps

# 6. Start port-forwarding (in a new/separate terminal, keep it open)
kubectl port-forward -n apps svc/api-api 8000:8000 &
kubectl port-forward -n apps svc/web-web 8080:80 &
kubectl port-forward -n apps svc/admin-admin 8081:80 &

# 7. Test access
curl http://localhost:8000/health/  # API
curl http://localhost:8080           # Web
curl http://localhost:8081           # Admin
```

## One-Command Fresh Start

```bash
make cluster-delete && make kind-up && make build-api build-web build-admin && make load-images && make deploy-local deploy-web deploy-admin && make install-nginx && make create-secrets
```

This destroys everything and rebuilds from scratch. Useful for a complete reset.
