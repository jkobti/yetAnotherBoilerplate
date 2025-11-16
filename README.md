# yetAnotherBoilerplate

> *The boilerplate for the new age.*
> *A boilerplate built for your AI agents.*


⚠️ Work in progress. Expect rapid iterations, incomplete wiring, and breaking adjustments while the boilerplate is assembled. Contributions and feedback are welcome as the vision takes shape.

---

## Quick Start: Local Kubernetes Deployment

Deploy the backend API to a local Kubernetes cluster:

```bash
make kind-up
make build-api build-web build-admin
make load-images
make deploy-local deploy-web deploy-admin
make install-nginx
make create-secrets
```

Or as a single command (builds and deploys everything):
```bash
make kind-up && make build-api && make load-images && make deploy-local && make install-nginx && make create-secrets
```

For detailed step-by-step instructions, access patterns, and troubleshooting, see **`charts/DEPLOYMENT.md`**.

---

## Documentation

- **Deployment Guide**: `charts/DEPLOYMENT.md` — complete end-to-end setup for local and production
- **Kubernetes Implementation Plan**: `Docs/04a-k8s-implementation-plan.md` — phased roadmap with current status
- **API Helm Chart**: `charts/api/README.md` — configuration, examples, troubleshooting
- **Ingress & TLS Setup**: `k8s/base/LOCAL_INGRESS_SETUP.md` — production-grade ingress and certificate management
- **Backend API**: `packages/backend/README.md` — Docker build, environment variables
- **Flutter Frontend**: `packages/flutter_app/README.md` — web builds, configuration
