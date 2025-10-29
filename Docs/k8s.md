# Kubernetes Platform Guide

This companion to `Docs/main.md` captures the Kubernetes-first operational model for the boiler project. Use it when evolving infrastructure automation, onboarding new services, or adjusting cluster-level workflows.

## 1. Activation & Deactivation Strategy

Provide consistent, low-effort ways to enable or disable components across environments.

### 1.1 Helm values (recommended)

- Drive component toggles through chart values, e.g.:

	values.yaml

	```yaml
	mobile:
		enabled: false
	workers:
		enabled: true
	```

- Guard template rendering with `{{- if .Values.<component>.enabled }}` checks.
- Backend feature specifics (Celery workers, transactional email, WebSockets, etc.) live in `Docs/backend-api.md`.

### 1.2 Kustomize overlays

- Maintain a base manifest set and use overlays for `production`, `staging`, and `local` that add or strip resources.

### 1.3 Environment variables / runtime flags

- Gate feature-level changes (not infra) with env vars read by the service (e.g., `FEATURE_X_ENABLED=true`).

### 1.4 Build-time toggles (mono-repo packages)

- Include or exclude packages from build/test matrices via CI configuration or workspace settings.

### 1.5 Feature flag systems

- For runtime gating across platforms, integrate a feature flag service and default to safe OFF values until explicitly enabled.

## 2. Repository Structure (reference)

This is the opinionated monorepo layout used throughout the docs. Adapt to multi-repo if preferred.

```
boiler/
├── README.md
├── charts/                  # Helm charts for each deployable component
├── k8s/                     # kustomize base + overlays
├── packages/
│   ├── web/                 # frontend web app (React/Vite)
│   ├── ios/                 # iOS app (Xcode project)
│   ├── android/             # Android app
│   ├── api/                 # backend API
│   └── worker/              # background worker
├── infra/                   # terraform / cloud infra (optional)
├── .github/workflows/       # example CI pipeline definitions
└── docs/                    # extended docs, runbooks, checklists
```

Notes:
- `charts/` contains Helm charts that accept `enabled` flags so you can deploy a subset of components.
- `k8s/overlays/local` should stay developer-friendly (e.g., kind or minikube + skaffold/tilt support).

## 3. Deployment Patterns

### 3.1 Helm toggles example

- To deploy only API and web components, set values like:

	```yaml
	api:
		enabled: true
	web:
		enabled: true
	mobile:
		enabled: false
	worker:
		enabled: false
	```

- Apply with `helm upgrade --install myrelease ./charts -f production-values.yaml`.

### 3.2 Kustomize overlay example

- Base contains `deployment-web.yaml`, `deployment-api.yaml`, and `deployment-worker.yaml`.
- Overlay `local` can remove `worker` via a `kustomization.yaml` that excludes or patches it out.

## 4. Developer Workflows

- **Local dev (fast iteration):** run backend locally (node/python) against local Postgres, start the web app with dev tooling (e.g., Vite), and rely on kind or minikube plus skaffold/tilt for Kubernetes parity.
- **Full cluster testing:** use kind + Helm to deploy overlays matching staging before merging.
- **Mobile development:** use local simulators with a locally running API (tunnel via ngrok or expose through a local ingress).

## 5. CI/CD Workflow

- **Pipeline stages:**
	1. Lint, static analysis, unit tests
	2. Build artifacts (Docker images, mobile builds), tag
	3. Integration tests on an ephemeral cluster (optional but recommended)
	4. Publish images to the registry
	5. Deploy via Helm using chart-value toggles
- Prefer ephemeral environments for pull requests; tear them down automatically after merge.

## 6. Observability & Security

- Ship optional charts for Prometheus, Grafana, and OpenTelemetry, controlled via Helm values.
- Configure Sentry in frontend builds through environment variables (DSNs) supplied at build time.
- Use cert-manager to manage TLS for ingress resources and issue mutual-auth certificates when services authenticate directly (e.g., frontend → backend mTLS).
- Store secrets in external systems (Vault, cloud secret managers) or use sealed-secrets for GitOps-friendly workflows.

## 7. Component Onboarding Checklist

1. Add the component folder under `packages/` with build/test scripts.
2. Create Helm charts or Kustomize manifests in `charts/` with an `enabled` value.
3. Update CI to build/test the component when toggled on or when its files change.
4. Document runtime env vars and configuration schema under `docs/`.

## 8. Validation & Quality Gates

- All unit tests and linters must pass.
- Run `helm template` with validators like `kubeval` or `conftest`.
- Optionally execute integration smoke tests against a disposable cluster before promotion.

## 9. Edge Cases & Gotchas

- Provide sensible defaults for empty or null configuration values in Helm charts.
- Use selective CI (path filters, test matrices) to keep monorepo build times manageable.
- Fail fast when required secrets are missing in production; ensure logs surface the missing key name.
- Version backend APIs to preserve mobile compatibility; coordinate releases across platforms.

## 10. Next-Step Ideas

1. Iterate the component list to reflect the default deployment profile.
2. Add concrete Helm chart skeletons and Kustomize bases as templates.
3. Document CI pipeline examples (e.g., GitHub Actions) alongside a kind/tilt local workflow.
4. (Optional) Scaffold a minimal API + web sample to validate the end-to-end deployment path.

## 11. Networking & Routing

Ingress controllers manage external traffic for the cluster. Key considerations:

- **Multi-domain routing:** map distinct hosts such as `app.yourdomain.com` (web) and `api.yourdomain.com` (backend API).
- **Controller choice:** NGINX remains a robust default; alternatives like Traefik or Istio ingress gateways fit particular needs.
- **TLS termination:** terminate TLS at the ingress via cert-manager issued certificates.

Document any additional ingress requirements (mTLS, custom headers, WAF integration) in environment-specific overlays.

---

Treat this guide as living documentation. When introducing new cluster services or deployment patterns, update this file and reference it from `Docs/main.md`.
