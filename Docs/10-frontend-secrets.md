# Frontend (Web & Admin) Secrets & Configuration

## Overview

**Key Difference**: Unlike the backend, web apps are **static builds**. Configuration values are compiled into the JavaScript at build time via `--dart-define`, not loaded from environment variables at runtime.

| Aspect                | Backend                            | Web/Admin                                               |
| --------------------- | ---------------------------------- | ------------------------------------------------------- |
| **When configured**   | At pod startup                     | At image build time                                     |
| **Storage**           | `.env` → K8s Secret → pod env vars | `env/local.json` → Docker build args → compiled into JS |
| **Can be changed**    | Yes, restart pod                   | No, rebuild image                                       |
| **Where values live** | Kubernetes Secret                  | Inside the compiled web bundle                          |

---

## 1. Local Development (Running Flutter Dev Server)

### Setup

```bash
# Copy the template
cp packages/flutter_app/env/local.json.example packages/flutter_app/env/local.json

# Edit with your values
nano packages/flutter_app/env/local.json

# Expected content:
{
    "API_BASE_URL": "http://localhost:8000",
    "PUSH_NOTIFICATIONS_ENABLED": "false",
    "FIREBASE_API_KEY": "your-firebase-api-key",
    ...
}
```

### Run Customer App

```bash
cd packages/flutter_app

# Option 1: Using env file (recommended)
flutter run -d chrome --dart-define-from-file=env/local.json

# Option 2: Using script
./scripts/run_with_env.zsh customer
```

### Run Admin Portal

```bash
cd packages/flutter_app

# Option 1: Using env file
flutter run -d chrome -t lib/main_admin.dart --dart-define-from-file=env/local.json

# Option 2: Using script
./scripts/run_with_env.zsh admin
```

### What's in `env/local.json`

```json
{
    "API_BASE_URL": "http://localhost:8000",           // Backend API endpoint
    "PUSH_NOTIFICATIONS_ENABLED": "false",             // Enable Firebase push
    "FIREBASE_API_KEY": "...",                         // Firebase Web App key
    "FIREBASE_APP_ID": "...",                          // Firebase App ID
    "FIREBASE_MESSAGING_SENDER_ID": "...",             // Firebase Sender ID
    "FIREBASE_PROJECT_ID": "...",                      // Firebase Project
    "FIREBASE_AUTH_DOMAIN": "...",                     // Firebase Auth Domain
    "FIREBASE_STORAGE_BUCKET": "...",                  // Firebase Storage
    "FIREBASE_VAPID_KEY": "...",                       // Firebase VAPID key (for push)
}
```

---

## 2. Docker Build (Creating Container Images)

### Build Customer Web Image

```bash
# Local/dev build
docker build -f packages/flutter_app/Dockerfile.web \
  --build-arg API_BASE_URL="http://localhost:8000" \
  --build-arg PUSH_NOTIFICATIONS_ENABLED="false" \
  -t yetanotherboilerplate/web:dev .

# Staging build
docker build -f packages/flutter_app/Dockerfile.web \
  --build-arg API_BASE_URL="https://api-staging.example.com" \
  --build-arg PUSH_NOTIFICATIONS_ENABLED="true" \
  --build-arg FIREBASE_API_KEY="staging-firebase-key" \
  --build-arg FIREBASE_PROJECT_ID="staging-project" \
  -t yetanotherboilerplate/web:staging .

# Production build
docker build -f packages/flutter_app/Dockerfile.web \
  --build-arg API_BASE_URL="https://api.example.com" \
  --build-arg PUSH_NOTIFICATIONS_ENABLED="true" \
  --build-arg FIREBASE_API_KEY="prod-firebase-key" \
  --build-arg FIREBASE_PROJECT_ID="prod-project" \
  -t yetanotherboilerplate/web:v1.0.0 .
```

### Build Admin Portal Image

```bash
docker build -f packages/flutter_app/Dockerfile.admin.web \
  --build-arg API_BASE_URL="https://api-staging.example.com" \
  --build-arg PUSH_NOTIFICATIONS_ENABLED="true" \
  --build-arg FIREBASE_API_KEY="staging-firebase-key" \
  --build-arg FIREBASE_PROJECT_ID="staging-project" \
  -t yetanotherboilerplate/admin:staging .
```

### Dockerfile Build Arguments

These are passed at build time and compiled into the app:

```dockerfile
ARG API_BASE_URL
ARG PUSH_NOTIFICATIONS_ENABLED
ARG FIREBASE_API_KEY
ARG FIREBASE_APP_ID
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_VAPID_KEY
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_STORAGE_BUCKET
```

All args are passed to `flutter build web --dart-define="KEY=VALUE"`.

---

## 3. Kubernetes Deployment (Using Pre-Built Images)

**Important**: The image is **already built** with configuration compiled in. You **cannot** change these values by setting Kubernetes environment variables or Secrets.

### Option A: Rebuild Image for Each Environment (Recommended)

```bash
# In your CI/CD pipeline:

# 1. Fetch secrets from your vault (AWS, HashiCorp, etc.)
API_BASE_URL=$(aws secretsmanager get-secret-value --secret-id prod/api_url)
FIREBASE_API_KEY=$(aws secretsmanager get-secret-value --secret-id prod/firebase_key)

# 2. Build image with secrets injected
docker build -f packages/flutter_app/Dockerfile.web \
  --build-arg API_BASE_URL="$API_BASE_URL" \
  --build-arg FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  -t ghcr.io/jkobti/yetanotherboilerplate/web:v1.0.0 .

# 3. Push to registry
docker push ghcr.io/jkobti/yetanotherboilerplate/web:v1.0.0

# 4. Deploy Helm chart (image already has config baked in)
helm install yab-web charts/web \
  --namespace apps \
  --set image.repository=ghcr.io/jkobti/yetanotherboilerplate/web \
  --set image.tag=v1.0.0
```

### Option B: Runtime Configuration (Advanced)

If you need to change config **without rebuilding**, serve a `config.json` from NGINX and fetch it at runtime:

```javascript
// In Flutter app (future implementation)
async function loadConfig() {
  const resp = await fetch('/assets/config.json');
  return resp.json();
}
```

Then mount the config via Kubernetes ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: apps
data:
  config.json: |
    {
      "API_BASE_URL": "https://api.example.com",
      "FIREBASE_PROJECT_ID": "prod-project"
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  template:
    spec:
      volumes:
        - name: config
          configMap:
            name: web-config
      containers:
        - name: web
          volumeMounts:
            - name: config
              mountPath: /usr/share/nginx/html/assets/config.json
              subPath: config.json
```

**Note**: This requires code changes to the Flutter app to fetch config at startup.

---

## 4. Configuration Reference

### `API_BASE_URL` (Required)

The backend API endpoint. Used by Dio HTTP client for all requests.

- **Local dev**: `http://localhost:8000`
- **K8s local**: `http://api.local.dev` or `http://api.apps.svc.cluster.local:8000`
- **Staging**: `https://api-staging.example.com`
- **Production**: `https://api.example.com`

### Firebase Credentials

Used for Cloud Messaging (push notifications) when `PUSH_NOTIFICATIONS_ENABLED=true`.

**Get from Firebase Console**:
1. Go to Project Settings > Your apps > Web app
2. Copy the Web App Config JSON
3. Populate the fields:
   - `FIREBASE_API_KEY`
   - `FIREBASE_APP_ID`
   - `FIREBASE_MESSAGING_SENDER_ID`
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_AUTH_DOMAIN`
   - `FIREBASE_STORAGE_BUCKET`
   - `FIREBASE_VAPID_KEY` (for web push; generate in Cloud Messaging settings)

**Security Note**: These are **public client-side credentials**. They're not secret and are exposed in the browser anyway. However, they should match your Firebase project and not be shared across environments.

### `PUSH_NOTIFICATIONS_ENABLED`

Boolean flag to enable Firebase Cloud Messaging.

- `true`: Initialize Firebase and register for push notifications
- `false`: Skip Firebase initialization (faster startup, no push)

---

## 5. Makefile Targets (Proposed)

These would automate building web images with injected configuration:

```bash
# Build web image for local dev
make build-web-local

# Build web image for staging (fetches secrets from vault)
make build-web-staging

# Build admin image for production (fetches secrets from vault)
make build-admin-prod
```

---

## 6. CI/CD Pipeline Pattern

Recommended flow for building and deploying web apps:

```yaml
# In your CI/CD (GitHub Actions, GitLab CI, etc.):

stages:
  - fetch_secrets    # AWS Secrets Manager, Vault, etc.
  - build_images     # Build with injected secrets
  - push_registry    # Push to container registry
  - deploy           # Deploy Helm chart with image tag
```

**Example GitHub Actions**:

```yaml
- name: Fetch prod secrets
  run: |
    echo "API_BASE_URL=$(aws secretsmanager ... prod/api_url)" >> $GITHUB_ENV
    echo "FIREBASE_API_KEY=$(aws secretsmanager ... prod/firebase_key)" >> $GITHUB_ENV

- name: Build web image
  run: |
    docker build -f packages/flutter_app/Dockerfile.web \
      --build-arg API_BASE_URL=${{ env.API_BASE_URL }} \
      --build-arg FIREBASE_API_KEY=${{ env.FIREBASE_API_KEY }} \
      -t ghcr.io/jkobti/yetanotherboilerplate/web:${{ github.sha }} .

- name: Deploy via Helm
  run: |
    helm install yab-web charts/web \
      --set image.tag=${{ github.sha }}
```

---

## 7. File Structure

```
packages/flutter_app/
├── env/
│   ├── local.json                # Actual local config (gitignored)
│   ├── local.json.example        # Template for local dev (committed)
│   ├── local.json.template       # Documentation template (committed)
│   ├── staging.json.example      # Template for staging (committed)
│   └── prod.json.example         # Template for production (committed)
├── Dockerfile.web                # Accepts build args
├── Dockerfile.admin.web          # Accepts build args
└── README.md                      # Configuration guide
```

---

## 8. Key Differences from Backend

| Aspect                | Backend                                           | Web/Admin                                   |
| --------------------- | ------------------------------------------------- | ------------------------------------------- |
| Config loading        | `packages/backend/.env` → Django reads at startup | `env/local.json` → compiled into JS         |
| When config changes   | Restart pod                                       | Rebuild image                               |
| Secret management     | K8s Secrets + env vars                            | Docker build args + vault                   |
| Can use K8s ConfigMap | Yes                                               | No (only for runtime-fetched config)        |
| CI/CD pattern         | Build once, config changes via pod restart        | Build per environment with secrets injected |

---

## Next Steps

1. **Local dev**: Create `env/local.json` from template, run with `flutter run --dart-define-from-file`
2. **Docker builds**: Use `--build-arg` to inject configuration
3. **Kubernetes**: Build images per environment in CI/CD, push to registry, deploy with Helm
4. **Secrets management**: Store secrets in AWS Secrets Manager / Vault / etc., fetch in CI, inject at build time
5. **Future enhancement**: Implement runtime `config.json` fetching for dynamic configuration without rebuilds
