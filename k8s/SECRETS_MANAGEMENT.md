# Kubernetes Secrets Management Guide

## Overview

This guide covers managing secrets for the backend API across local development, staging, and production environments.

**Three-tier approach**:
1. **Local dev**: Simple YAML secrets in git (gitignored), or Makefile automation
2. **Staging**: External Secrets Operator (future) or sealed secrets
3. **Production**: SealedSecrets or External Secrets Operator connecting to AWS Secrets Manager / Vault

---

## 1. Local Development (kind cluster)

### Quick Start

```bash
# Copy the template
cp packages/backend/.env.k8s.example packages/backend/.env.k8s

# Edit with local values
nano packages/backend/.env.k8s

# Create secrets from the env file
make create-secrets-from-env ENV_FILE=packages/backend/.env.k8s

# Or use the simple one-liner
make create-secrets
```

### Method A: Using Environment File (Recommended)

This reads from `packages/backend/.env.k8s` and creates the Kubernetes Secret.

**Setup**:
```bash
# Copy template
cp packages/backend/.env.k8s.example packages/backend/.env.k8s

# Edit with your local values (same format as Django .env)
DEBUG=true
SECRET_KEY=dev-key
DATABASE_URL=sqlite:///db.sqlite3
API_DOCS_ENABLED=true
CORS_ALLOW_ALL_ORIGINS=true
MAGIC_LINK_VERIFY_URL=http://localhost:5173
# ... fill in other values

# Create secrets
make create-secrets-from-env
```

**How it works**:
- Makefile target reads `packages/backend/.env.k8s`
- Uses `kubectl create secret generic` with `--from-env-file`
- Creates a Secret named `api-env` in the `apps` namespace
- Deployment injects it via `envFrom: secretRef`

### Method B: Using YAML Manifest (Alternative)

If you prefer declarative YAML:

```bash
# Copy the template
cp k8s/overlays/local/secrets.yaml.example k8s/overlays/local/secrets.yaml

# Edit values directly in YAML
nano k8s/overlays/local/secrets.yaml

# Apply
kubectl apply -f k8s/overlays/local/secrets.yaml
```

### Verify Secrets Created

```bash
# List secrets
kubectl get secrets -n apps

# View secret keys (not values)
kubectl describe secret api-env -n apps

# Decode a specific value (if you dare—don't log this!)
kubectl get secret api-env -n apps -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

### Update/Rotate Secrets

```bash
# Using env file (idempotent—safe to re-run)
make create-secrets-from-env

# Or manually
kubectl delete secret api-env -n apps
make create-secrets-from-env
```

---

## 2. Staging Environment

### Setup (Without External Secrets Operator)

For now, treat staging like local: use a gitignored `secrets.yaml` file.

```bash
# Copy template
cp k8s/overlays/staging/secrets.yaml.example k8s/overlays/staging/secrets.yaml

# Edit with staging values (real DB, real API keys, etc.)
nano k8s/overlays/staging/secrets.yaml

# Apply
kubectl apply -f k8s/overlays/staging/secrets.yaml
```

### Future: External Secrets Operator

When you're ready to integrate with AWS Secrets Manager or HashiCorp Vault:

1. Install ESO in the cluster
2. Create a `SecretStore` pointing to your secret backend
3. Create an `ExternalSecret` manifest
4. ESO automatically syncs secrets into Kubernetes Secrets

See `04-k8s.md` for detailed ESO setup instructions.

---

## 3. Production Environment

### Setup (Without External Secrets Operator)

```bash
# Copy template
cp k8s/overlays/production/secrets.yaml.example k8s/overlays/production/secrets.yaml

# Edit with production values
# CRITICAL: Use strong random keys, real database URLs, real API credentials
nano k8s/overlays/production/secrets.yaml

# Apply
kubectl apply -f k8s/overlays/production/secrets.yaml
```

### Best Practice: SealedSecrets or ESO

For production, **do not store plaintext secrets in version control**, even in gitignored files.

**Option 1: SealedSecrets** (cluster-specific encryption, can commit encrypted YAML)
```bash
# Encrypt a secret
echo -n "my-secret-value" | kubectl create secret generic my-secret \
  --dry-run=client --from-file=/dev/stdin \
  -o yaml | kubeseal -f - > sealed-secret.yaml

# Commit sealed-secret.yaml to git (encrypted)
# Controller auto-decrypts in the cluster
```

**Option 2: External Secrets Operator** (fetch from AWS/Vault/etc.)
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-env
  namespace: apps
spec:
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: api-env
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: prod/database_url
    - secretKey: JWT_SECRET
      remoteRef:
        key: prod/jwt_secret
```

---

## 4. File Structure

```
packages/backend/
├── .env.example         # Django .env template (committed)
├── .env.k8s.example     # Kubernetes secrets template (committed)
├── .env.k8s             # ACTUAL local secrets (gitignored)
└── ...

k8s/
├── base/                # Base manifests (no secrets)
│   ├── namespaces.yaml
│   └── serviceaccounts.yaml
└── overlays/
    ├── local/
    │   ├── secrets.yaml.example       # Template (committed)
    │   ├── secrets.yaml               # Actual local secrets (gitignored)
    │   ├── kustomization.yaml
    │   └── deployment-patch.yaml
    ├── staging/
    │   ├── secrets.yaml.example       # Template (committed)
    │   ├── secrets.yaml               # Actual staging secrets (gitignored)
    │   ├── kustomization.yaml
    │   └── deployment-patch.yaml
    ├── production/
    │   ├── secrets.yaml.example       # Template (committed)
    │   ├── secrets.yaml               # Actual prod secrets (gitignored)
    │   ├── kustomization.yaml
    │   └── deployment-patch.yaml
    └── .gitignore                      # Prevents committing secrets
```

---

## 5. Environment Variables Reference

All backend environment variables are documented in `packages/backend/.env.k8s.example`:

### Core Settings
- `DEBUG` — Development mode (false for staging/prod)
- `SECRET_KEY` — Django secret key (strong random value)
- `ALLOWED_HOSTS` — Comma-separated hostnames
- `API_DOCS_ENABLED` — Enable Swagger/ReDoc

### Database
- `DATABASE_URL` — Connection string (SQLite for local, PostgreSQL for prod)

### Email
- `EMAIL_PROVIDER` — Provider name (console, resend, sendgrid, etc.)
- `RESEND_API_KEY` — API key for Resend
- `DEFAULT_FROM_EMAIL` — Sender email

### Firebase / Push Notifications
- `GOOGLE_SERVICE_ACCOUNT_JSON` — Firebase service account (raw JSON or file path)
- `FCM_SERVER_KEY` — Legacy Firebase key (deprecated)

### Magic Link Auth
- `MAGIC_LINK_VERIFY_URL` — Frontend verification page (absolute URL, required)
- `MAGIC_LINK_EXPIRY_MINUTES` — Token validity (default: 5 min)
- `MAGIC_LINK_DEBUG_ECHO_TOKEN` — Echo token in response (debug only)

### CORS
- `CORS_ALLOW_ALL_ORIGINS` — Allow all origins (true for local, false for prod)
- `CORS_ALLOWED_ORIGIN_REGEXES` — Comma-separated regex patterns (when not allowing all)

### Caching
- `REDIS_URL` — Redis connection (optional, for caching/sessions)

### Authentication
- `JWT_SECRET` — JWT signing key (strong random value)

### Logging
- `LOG_LEVEL` — Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)

---

## 6. Makefile Targets

### Create Secrets from Environment File

```bash
# Read from packages/backend/.env.k8s
make create-secrets-from-env

# Or specify custom path
make create-secrets-from-env ENV_FILE=.env.staging
```

### Create Secrets (Old Hardcoded Method—Deprecated)

```bash
# Uses hardcoded values in Makefile (for backwards compat)
make create-secrets-old
```

---

## 7. Troubleshooting

### Secret not found when pod starts

```bash
# Check if Secret exists
kubectl get secret api-env -n apps

# If missing, create it
make create-secrets-from-env

# Restart pod to pick up new Secret
kubectl rollout restart deployment/yab-api -n apps
```

### Pod can't read environment variables

```bash
# Verify deployment references the secret
kubectl get deployment yab-api -n apps -o yaml | grep -A 10 envFrom

# Check if secretRef name matches actual Secret name
kubectl get secret -n apps
```

### Updating a secret

```bash
# Method 1: Recreate from env file
make create-secrets-from-env

# Method 2: Edit Secret directly (not recommended for production)
kubectl edit secret api-env -n apps

# Method 3: Delete and recreate
kubectl delete secret api-env -n apps
make create-secrets-from-env

# After any update, restart pods
kubectl rollout restart deployment/yab-api -n apps
```

### View current secret values (use with care!)

```bash
# List all keys in the secret
kubectl get secret api-env -n apps -o jsonpath='{.data}' | jq 'keys'

# Decode specific key (don't log production secrets!)
kubectl get secret api-env -n apps -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

---

## 8. Next Steps

- **Staging/Production**: Integrate with External Secrets Operator or SealedSecrets
- **Rotation**: Implement automated secret rotation with your chosen solution
- **Audit**: Enable Kubernetes audit logging to track secret access
- **RBAC**: Restrict which ServiceAccounts can read secrets (see `SECURITY.md`)
