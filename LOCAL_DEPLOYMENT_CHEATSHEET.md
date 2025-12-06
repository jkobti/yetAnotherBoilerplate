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
make deploy-observability
make deploy-local deploy-web deploy-admin
make install-nginx
make create-secrets
```

Or as a one-liner:
```bash
make kind-up && make build-api build-web build-admin && make load-images && make deploy-observability && make deploy-local deploy-web deploy-admin && make install-nginx && make create-secrets
```

## Full Deployment with Workers (Optional)

Includes Redis and Celery worker deployment.

```bash
make kind-up
make build-api build-web build-admin
make load-images
make deploy-observability
make deploy-redis
make deploy-local deploy-web deploy-admin
make deploy-worker
make install-nginx
make create-secrets
```

Or as a one-liner:
```bash
make kind-up && make build-api build-web build-admin && make load-images && make deploy-observability && make deploy-redis && make deploy-local deploy-web deploy-admin && make deploy-worker && make install-nginx && make create-secrets
```

## Update Existing Deployment

If your cluster is already running and you want to deploy code changes or enable workers:

```bash
make build-api build-web build-admin
make load-images
make deploy-observability
make deploy-redis
make deploy-local deploy-web deploy-admin
make deploy-worker
make create-secrets
```

Or as a one-liner:
```bash
make build-api build-web build-admin && make load-images && make deploy-observability && make deploy-redis && make deploy-local deploy-web deploy-admin && make deploy-worker && make create-secrets
```

## Step-by-Step Breakdown

| Step | Command                                     | What It Does                                   | Time  |
| ---- | ------------------------------------------- | ---------------------------------------------- | ----- |
| 1    | `make kind-up`                              | Creates local Kubernetes cluster (`yab-local`) | ~30s  |
| 2    | `make build-api build-web build-admin`      | Builds Docker images for all services          | ~3-5m |
| 3    | `make load-images`                          | Loads images into kind cluster                 | ~30s  |
| 4    | `make deploy-observability`                 | Deploys Prometheus & Grafana stack             | ~2m   |
| 5    | `make deploy-local deploy-web deploy-admin` | Deploys services + PostgreSQL to cluster       | ~2m   |
| 6    | `make install-nginx`                        | Installs NGINX ingress controller              | ~1m   |
| 7    | `make create-secrets`                       | Creates Kubernetes secrets from `.env.k8s`     | ~10s  |

**Optional Steps:**

| Step | Command              | What It Does                           |
| ---- | -------------------- | -------------------------------------- |
| 8    | `make deploy-redis`  | Deploys Redis (required for worker)    |
| 9    | `make deploy-worker` | Enables Celery worker (requires Redis) |

**Total time: ~9-12 minutes**

Services are immediately accessible at:
- API: http://localhost:8000
- Web: http://localhost:8080
- Admin: http://localhost:8081
- Grafana: http://localhost:3000 (user: admin / pass: admin)

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

3. **Copy the frontend env file** that drives Flutter web builds:
   ```bash
   cp packages/flutter_app/env/local.json.example packages/flutter_app/env/local.json
   ```
   Then edit `packages/flutter_app/env/local.json` to set values like `API_BASE_URL` and `APP_MODE` (`b2c` default, set to `b2b` to enable team UI). `make build-web` and `make build-admin` read this file automatically.

4. **Verify you have required tools:**
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

### Issue: Port already allocated (8000, 8080, 8081, 3000)

**Symptom:** `make kind-up` fails with error:
```
Bind for 0.0.0.0:8081 failed: port is already allocated
```

**Solution:** This should be handled automatically by `make cluster-delete`, but if it still occurs:

1. **Wait a few seconds** - Docker needs time to release port bindings after cluster deletion
2. **Run cluster-delete again**:
   ```bash
   make cluster-delete
   ```

If the issue persists, restart Docker Desktop from the menu (macOS/Windows) or restart the Docker daemon (Linux).

## Accessing Services

### Direct Access (No Port-Forwarding Required)

All services are automatically accessible via the kind cluster's port mappings:

- **API:** http://localhost:8000
- **Web:** http://localhost:8080
- **Admin:** http://localhost:8081
- **Grafana:** http://localhost:3000 (user: admin / pass: admin)

- **API**: http://localhost:8000/health/ (or any API endpoint)
- **Web**: http://localhost:8080
- **Admin**: http://localhost:8081

**Quick test:**
```bash
curl http://localhost:8000/health/
curl http://localhost:8080
curl http://localhost:8081
```

The services use `hostPort` bindings in their Kubernetes deployments, which are automatically mapped to your local machine through kind's `extraPortMappings` configuration.

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
- **Services are automatically accessible** via hostPort bindings—no manual port-forwarding needed
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

# 6. Test access (services are automatically available)
curl http://localhost:8000/health/  # API
curl http://localhost:8080           # Web
curl http://localhost:8081           # Admin
```

## One-Command Fresh Start

```bash
make cluster-delete && make kind-up && make build-api build-web build-admin && make load-images && make deploy-local deploy-web deploy-admin && make install-nginx && make create-secrets
```

This destroys everything and rebuilds from scratch. Useful for a complete reset.
