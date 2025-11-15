# Backend Secrets & Environment Variables

## Quick Start

```bash
# 1. Copy the template
cp packages/backend/.env.k8s.example packages/backend/.env.k8s

# 2. Edit with your values
nano packages/backend/.env.k8s

# 3. Create Kubernetes Secret
make create-secrets

# 4. Deploy API
make deploy-local
```

---

## File Locations

| File                                      | Purpose                                    | Committed?   |
| ----------------------------------------- | ------------------------------------------ | ------------ |
| `packages/backend/.env.example`           | Django .env template for local dev         | ✅ Yes        |
| `packages/backend/.env.k8s.example`       | Kubernetes secrets template (all env vars) | ✅ Yes        |
| `packages/backend/.env.k8s`               | **Your actual local K8s secrets**          | ❌ Gitignored |
| `k8s/overlays/local/secrets.yaml.example` | K8s Secret YAML template                   | ✅ Yes        |
| `k8s/overlays/local/secrets.yaml`         | **Your actual local K8s Secret YAML**      | ❌ Gitignored |

---

## Running Backend Locally (Outside K8s)

```bash
cd packages/backend

# Option 1: Use .env file (reads from packages/backend/.env)
python manage.py runserver

# Option 2: Use environment variables
export DEBUG=true
export SECRET_KEY=dev-key
export ALLOWED_HOSTS=localhost,127.0.0.1
export DATABASE_URL=sqlite:///db.sqlite3
python manage.py runserver
```

---

## Running Backend on K8s (Local kind Cluster)

```bash
# 1. Create kind cluster
make kind-up

# 2. Create K8s namespace and service account
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/base/serviceaccounts.yaml

# 3. Create secrets from env file
cp packages/backend/.env.k8s.example packages/backend/.env.k8s
# Edit .env.k8s with values
make create-secrets

# 4. Build and deploy API
make deploy-local

# 5. Check status
kubectl get pods -n apps
kubectl logs -f deployment/yab-api -n apps
```

---

## Environment Variables Explained

All variables are documented in `packages/backend/.env.k8s.example`. Here are the key ones:

### Core Django
- `DEBUG`: Enable debug mode (false in production)
- `SECRET_KEY`: Django secret key (must be strong)
- `ALLOWED_HOSTS`: Comma-separated hostnames

### Database
- `DATABASE_URL`: Connection string
  - Local: `sqlite:///db.sqlite3`
  - Production: `postgresql://user:pass@host:5432/db`

### Email
- `EMAIL_PROVIDER`: console, resend, sendgrid, etc.
- `RESEND_API_KEY`: Resend email API key

### Magic Link Auth
- `MAGIC_LINK_VERIFY_URL`: Frontend verification page (required)
  - Must be absolute URL: `https://example.com` or `https://example.com/auth`
- `MAGIC_LINK_EXPIRY_MINUTES`: Token validity window (default: 5 min)
- `MAGIC_LINK_DEBUG_ECHO_TOKEN`: Echo token in response (debug only)

### Firebase / Push Notifications
- `GOOGLE_SERVICE_ACCOUNT_JSON`: Firebase service account (raw JSON)
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account JSON file

### CORS
- `CORS_ALLOW_ALL_ORIGINS`: true for local, false for production
- `CORS_ALLOWED_ORIGIN_REGEXES`: Regex patterns (when not allowing all)

### Caching
- `REDIS_URL`: Redis connection (optional)

---

## Troubleshooting

### Pod won't start

```bash
# Check logs
kubectl logs deployment/yab-api -n apps

# Likely causes:
# 1. Secret not created
kubectl get secrets -n apps

# 2. Secret missing required keys
kubectl describe secret api-env -n apps

# 3. Database connection failed
# Check DATABASE_URL in secret
```

### Update secrets

```bash
# Option 1: Recreate from env file
make create-secrets

# Option 2: Delete and recreate
kubectl delete secret api-env -n apps
make create-secrets

# Restart pod
kubectl rollout restart deployment/yab-api -n apps
```

### View secrets (carefully!)

```bash
# List keys
kubectl get secret api-env -n apps -o jsonpath='{.data}' | jq 'keys'

# Decode one key (don't log production values!)
kubectl get secret api-env -n apps -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

---

## Full Documentation

See `k8s/SECRETS_MANAGEMENT.md` for comprehensive guide including:
- Multi-environment setup (staging/production)
- External Secrets Operator integration
- SealedSecrets encryption
- Secret rotation procedures
- RBAC and audit logging
