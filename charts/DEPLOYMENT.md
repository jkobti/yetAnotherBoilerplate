# Deployment Guide

Complete end-to-end instructions for deploying yetAnotherBoilerplate to local Kubernetes (kind) and production environments.

## Table of Contents

1. [Local Development (kind)](#local-development-kind)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Access Patterns](#access-patterns)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **Docker Desktop** with Kubernetes support (or similar container runtime)
- **Helm 3.x** — install via `brew install helm` (Mac) or [official docs](https://helm.sh/docs/intro/install/)
- **kubectl** — usually installed with Docker Desktop; verify with `kubectl version`
- **kind** — `brew install kind` (Mac)
- **Make** — usually pre-installed on macOS/Linux

### Verify Installation

```bash
docker --version
helm version
kubectl version --client
kind version
make --version
```

---

## Local Development (kind)

### Quick Start: One-Command Deployment

```bash
# Full deployment including images, cluster, and secrets
make kind-up && make build-api && make load-images && make deploy-local && make install-nginx && make create-secrets
```

Or step-by-step:
```bash
make kind-up
make build-api build-web build-admin
make load-images
make deploy-local deploy-web deploy-admin
make install-nginx
make create-secrets
```

This automates:
1. Creates local kind cluster (`yab-local`) with port mappings for API (8000), web (8080), ingress (80/443)
2. Creates namespaces: `apps` (workloads), `ingress` (ingress controller), `observability` (monitoring—reserved)
3. Builds all Docker images (API, web, admin)
4. Loads images into kind cluster
5. Creates service accounts and deploys Helm charts to `apps` namespace
6. Deploys PostgreSQL database
7. Installs NGINX ingress controller
8. Creates Kubernetes secrets from environment variables (required for migrations and runtime)

**Expected output:**
```
✓ kind cluster created
✓ Namespaces created
✓ All images built and loaded
✓ Service accounts created
✓ API, web, and admin charts deployed
✓ Pods ready
✓ NGINX ingress installed
✓ Secrets created
```

**Important:** Secrets must be created **before** or **immediately after** deployment because the API pod runs Django migrations in its init container, which requires the `api-env` secret with database credentials and other environment variables.

### Step-by-Step Deployment (Manual)

If you prefer to deploy gradually or debug each step:

#### 1. Create the Local Cluster

```bash
make kind-up
```

Verify:
```bash
kubectl cluster-info
kubectl get nodes
```

Expected output:
```
NAME                    STATUS   ROLES           AGE   VERSION
yab-local-control-plane Ready    control-plane   1m    v1.34.0
```

#### 2. Verify Namespaces

```bash
kubectl get namespaces
```

Expected output:
```
NAME            STATUS   AGE
apps            Active   1m
ingress         Active   1m
observability   Active   1m
```

#### 3. Build API Image

```bash
make build-api
```

This builds the backend API Docker image and tags it as `yetanotherboilerplate/api:dev` (non-root user, multi-stage build).

Verify:
```bash
docker images | grep yetanotherboilerplate/api
```

Expected output:
```
yetanotherboilerplate/api    dev     abc123def456   1m   95MB
```

#### 4. Deploy API Chart

```bash
make deploy-local
```

This runs:
```bash
kubectl apply -f k8s/base/namespaces.yaml
helm install api charts/api/ -n apps
```

Verify:
```bash
kubectl get pods -n apps
kubectl get svc -n apps
```

Expected output:
```
NAME                   READY   STATUS    RESTARTS   AGE
api-api-5d4f8c9bx     1/1     Running   0          30s

NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
api-api       ClusterIP   10.96.200.100  <none>        8000/TCP   30s
```

#### 5. Verify Pod Health

```bash
kubectl logs -n apps -l app.kubernetes.io/name=api
```

Expected log output:
```
[2025-11-14 10:30:45 +0000] [1] [INFO] Starting gunicorn 21.2.0
[2025-11-14 10:30:45 +0000] [1] [INFO] Listening at: http://0.0.0.0:8000 (1)
```

Check readiness probe:
```bash
kubectl describe pod -n apps -l app.kubernetes.io/name=api | grep -A5 "Readiness"
```

Expected output:
```
Readiness:      http-get http://:8000/health/ delay=10s timeout=5s period=10s #success=1 #failure=3
```

#### 6. Deploy Web & Admin Frontends (Optional)

The web and admin frontends are optional and **disabled by default**. Deploy them using the same pattern:

```bash
# Build and deploy web frontend
make build-web
make deploy-web

# Build and deploy admin frontend
make build-admin
make deploy-admin

# Verify all pods are running
kubectl get pods -n apps
```

Expected output:
```
NAME                      READY   STATUS    RESTARTS   AGE
api-api-5d4f8c9bx        1/1     Running   0          2m
web-web-7e4f2c1ay        1/1     Running   0          30s
admin-admin-3k8f9c2bz    1/1     Running   0          30s
```

---

## Access Patterns

### Option A: Port-Forward (Recommended for Local Dev)

Use `kubectl port-forward` to access services locally. This works reliably on all platforms (Mac, Windows, Linux).

```bash
# Forward API to localhost:8000
kubectl port-forward -n apps svc/api-api 8000:8000

# Forward web frontend to localhost:8080
kubectl port-forward -n apps svc/web-web 8080:80

# Forward admin frontend to localhost:8081
kubectl port-forward -n apps svc/admin-admin 8081:80

# In another terminal, test the services
curl http://localhost:8000/health/    # API health check
curl http://localhost:8080/           # Web frontend
curl http://localhost:8081/           # Admin frontend
```

Expected responses:
```
API:     {"status": "ok"}
Web:     <HTML content of web app>
Admin:   <HTML content of admin app>
```

Keep the port-forward terminal(s) open while developing.

### Option B: Ingress (Production Pattern, Local Setup)

Ingress works for testing production-like routing, but has limitations on kind + Mac/Windows Docker Desktop.

#### Setup Ingress Controller

```bash
make install-nginx
```

This installs the NGINX ingress controller into the `ingress` namespace.

Verify:
```bash
kubectl get pods -n ingress | grep nginx-ingress-controller
```

Expected output:
```
nginx-ingress-controller-7d8f7c9bx-xyz   1/1     Running   0   30s
```

#### Setup Local DNS (Optional)

```bash
make setup-local-dns
```

This adds `api.local.dev`, `app.local.dev`, and `admin.local.dev` to `/etc/hosts` (requires sudo password prompt).

Verify:
```bash
cat /etc/hosts | grep local.dev
```

Expected output:
```
127.0.0.1 api.local.dev
127.0.0.1 app.local.dev
127.0.0.1 admin.local.dev
```

#### Deploy Ingress

```bash
make deploy-ingress
```

This upgrades the API chart with ingress enabled.

Verify:
```bash
kubectl get ingress -n apps
```

Expected output:
```
NAME     CLASS   HOSTS          ADDRESS         PORTS   AGE
api-api  nginx   api.local.dev  10.96.10.100    80      30s
```

#### Access via Ingress

**Linux / Kind on native:**
```bash
curl http://api.local.dev/health/
# or with TLS (if cert-manager configured):
curl https://api.local.dev/health/ --insecure
```

**Mac / Windows (kind on Docker Desktop) — Known Limitation:**

Ingress is not directly accessible from the host due to Docker networking. Use one of these workarounds:

**Workaround 1: kubectl port-forward (recommended)**
```bash
kubectl port-forward -n ingress svc/nginx-ingress-controller 80:80 443:443
curl http://api.local.dev/health/ -H "Host: api.local.dev"
```

**Workaround 2: docker exec (for testing)**
```bash
docker exec yab-local-control-plane curl -s http://localhost:80/health/ -H "Host: api.local.dev"
```

See `k8s/base/LOCAL_INGRESS_SETUP.md` for detailed ingress setup and production deployment guidance.

---

## Troubleshooting

### Pod Not Ready

**Symptom:** `kubectl get pods -n apps` shows `Pending` or `ImagePullBackOff`

**Diagnosis:**
```bash
kubectl describe pod -n apps -l app.kubernetes.io/name=api
kubectl logs -n apps -l app.kubernetes.io/name=api
```

**Common Issues:**

1. **Image not found:**
   ```bash
   # Make sure image was built
   docker images | grep yetanotherboilerplate/api

   # If missing, rebuild and load into kind
   make build-api
   kind load docker-image yetanotherboilerplate/api:dev --name yab-local
   ```

2. **Pod CrashLoopBackOff:**
   ```bash
   # Check logs for errors
   kubectl logs -n apps -l app.kubernetes.io/name=api --previous

   # Common: environment variables missing
   # See charts/api/values.yaml for required variables
   ```

3. **Readiness probe failing:**
   ```bash
   # Test endpoint manually
   kubectl exec -n apps -it <pod-name> -- curl -s http://localhost:8000/health/

   # Verify probes in deployment
   kubectl get deployment -n apps api-api -o yaml | grep -A10 "livenessProbe\|readinessProbe"
   ```

### Service Not Accessible

**Symptom:** `curl http://localhost:8000/health/` times out or refuses connection

**Diagnosis:**
```bash
# Check service endpoints
kubectl get endpoints -n apps api-api

# Port-forward and test
kubectl port-forward -n apps svc/api-api 8000:8000 &
curl http://localhost:8000/health/
```

### Ingress Not Routing

**Symptom:** NGINX controller running but `curl` returns 502 or timeout

**Diagnosis:**
```bash
# Check ingress resource
kubectl describe ingress -n apps api-api

# Check NGINX controller logs
kubectl logs -n ingress -l app.kubernetes.io/name=ingress-nginx

# Test from inside cluster
kubectl exec -n ingress <nginx-pod> -- curl -s http://api-api.apps:8000/health/
```

### kind Cluster Won't Start

**Symptom:** `make kind-up` fails with Docker error

**Diagnosis:**
```bash
# Check Docker is running
docker ps

# Check kind config
cat k8s/kind-config.yaml

# Try manual creation with verbose output
kind create cluster --config k8s/kind-config.yaml --name yab-local --verbosity 2

# Cleanup and retry
kind delete cluster --name yab-local
make kind-up
```

### Make Targets Not Found

**Symptom:** `make: *** No rule to make target 'kind-up'`

**Diagnosis:**
```bash
# Verify Makefile exists in root
ls -la Makefile

# Check current directory
pwd
# Should be /Users/joseph/Documents/projects/boiler

# List available targets
make help
```

---

## Cleanup

### Stop and Remove Local Cluster

```bash
make kind-down
```

This deletes the kind cluster and all deployed resources.

Verify:
```bash
kind get clusters
# Should be empty or not list yab-local
```

### Remove Docker Image

```bash
docker rmi yetanotherboilerplate/api:dev
```

### Remove /etc/hosts Entry (if added)

```bash
# Manually edit /etc/hosts and remove the api.local.dev line
sudo nano /etc/hosts

# Or use sed to remove it
sudo sed -i '' '/api.local.dev/d' /etc/hosts
```

---

## Next Steps

- **Configure Ingress/TLS**: See `k8s/base/LOCAL_INGRESS_SETUP.md` for production setup
- **Customize Charts**:
  - API: `charts/api/README.md`
  - Web Frontend: `charts/web/README.md`
  - Admin Frontend: `charts/admin/README.md`
- **Setup Observability**: Phase 4—Prometheus/Grafana (pending)
- **CI/CD Integration**: Phase 7—automated image builds and deployments

---

## Related Documentation

- **Kubernetes Plan**: `Docs/04a-k8s-implementation-plan.md`
- **API Chart Reference**: `charts/api/README.md`
- **Web Chart Reference**: `charts/web/README.md`
- **Admin Chart Reference**: `charts/admin/README.md`
- **Ingress & TLS Setup**: `k8s/base/LOCAL_INGRESS_SETUP.md`
- **Backend API**: `packages/backend/README.md`
- **Flutter Frontend**: `packages/flutter_app/README.md`
