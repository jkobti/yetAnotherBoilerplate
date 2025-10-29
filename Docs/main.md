## Boiler

This document is the starting point for the `boiler` project — a reusable, production-ready boilerplate that you can use as the foundation for future projects.

The goal: define a flexible, modular starter that supports frontend and backend apps (web, iOS, Android, APIs, workers), is deployable to Kubernetes, and allows components to be easily activated or deactivated.

## High-level contract

- Inputs: application code (frontend, mobile, backend), configuration (helm/kustomize values, env vars), and infrastructure configuration (Kubernetes manifests, Helm charts).
- Outputs: a deployable artifact per component (Docker images, mobile build artifacts), Helm charts/kustomize overlays, CI/CD pipelines that produce and deploy to Kubernetes clusters.
- Error modes: misconfigured manifests, missing secrets, incompatible component versions; documentation will include validation checks and a checklist for pre-deploy.

## Goals and principles

- Modular: components can be included or removed with minimal changes.
- Kubernetes-first: every component should be deployable on Kubernetes (dev-to-prod parity).
- Poly-platform frontends: support Web, iOS, and Android with shared patterns where reasonable.
- Developer experience: easy local development, clear workflows, and reproducible builds.
- Secure by default: encourage secrets management, TLS, least-privilege RBAC, and CI security checks.

## Components by Layer

To clarify responsibilities, components are broken down by where they live: the underlying platform (Kubernetes), the backend services, and the frontend clients.

### 1. Platform & In-Cluster Services

These are the infrastructure-level components deployed into the Kubernetes cluster, typically managed via Helm or Kustomize. They provide the runtime environment for your applications.

**Core Platform Services:**
- **Kubernetes Base:** Deployments, Services, Ingresses, ConfigMaps, and Secrets forming the foundation for running apps.
- **CI/CD Pipeline:** The automated system for building, testing, and deploying all components.

**Optional Platform Services:**
- **Database:** PostgreSQL running as a stateful service within the cluster.
- **Caching:** Redis for in-memory caching.
- **Logging:** A cluster-wide logging aggregator like Loki or Fluentd.
- **Observability:** Prometheus for metrics collection, Grafana for dashboards, and an OpenTelemetry collector for traces.
- **Authentication:** A self-hosted identity service like Keycloak.
- **Secrets Management:** A controller for Sealed Secrets or an internal Vault instance.
- **Object Storage:** An S3-compatible object storage service (e.g., MinIO).
- **Container Registry:** A private Docker registry (e.g., Harbor, Docker Registry) for storing and managing container images within the cluster.
- **Ingress Controller:** A dedicated controller (e.g., NGINX, Traefik) to manage routing rules, enabling features like host-based routing for different domains.

### 2. Backend Application Components

The server-side stack centers on Django + DRF backed by PostgreSQL. Treat migrations, rate limiting, and email integrations as baseline capabilities, and layer in workers, realtime transport, and storage adapters as needed. Refer to `Docs/backend-api.md` for the authoritative breakdown of required features, optional add-ons, and configuration guidance.

### 3. Frontend Application Components

These are the features built into the client-side application code (Flutter for web, iOS, and Android).

**Core Frontend Features:**
- **UI Framework:** Flutter for cross-platform web, iOS, and Android development.
- **API Client:** Logic for communicating with the backend API.

**Optional Frontend Features:**
- **Error Reporting:** Sentry integration for capturing and reporting client-side exceptions.
- **Authentication Flow:** UI components for login, logout, and user session management.
- **Feature Flag Integration:** Client-side logic to show/hide features based on flags.
- **Push Notifications:** Integration with Firebase Cloud Messaging (FCM) for push notifications.
- **WebSocket Client:** Flutter WebSocket implementation for real-time communication with the backend (for chat, live notifications, collaborative features).
- **Direct Object Storage Access:** Support for direct uploads/downloads to an object storage service using pre-signed URLs provided by the backend.

## Activation / Deactivation strategy

We want a few consistent, low-effort ways to enable or disable components across environments.

1) Helm values (recommended for Kubernetes deployments)

- Use feature flags in chart values, e.g.:

	values.yaml

	```yaml
	mobile:
		enabled: false
	workers:
		enabled: true
	```

Backend features such as Celery workers, transactional email, and WebSocket support are covered in-depth in `Docs/backend-api.md`; reference that document when enabling those capabilities.

- Each chart's templates should guard resource creation with `{{- if .Values.<component>.enabled }}` checks.

2) Kustomize overlays

- Keep a base set of manifests and use overlays for `production`, `staging`, and `local` where components are added/removed.

3) Environment variables / runtime flags

- For feature-level toggles (not infra), use env variables read by the service (e.g., `FEATURE_X_ENABLED=true`).

4) Build-time toggles (mono-repo packages)

- In monorepos, include or exclude packages from build/test matrices via CI config or workspace settings.

5) Feature flag systems

- For runtime feature gating across platforms, integrate a feature flag service and default to safe OFF values until enabled.

## Project structure (example)

This is an opinionated monorepo layout. Feel free to adapt to multi-repo if preferred.

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
- `k8s/overlays/local` should be developer-friendly and allow running the system locally (e.g., using `kind` or `minikube`).

## Example: enable/disable a component with Helm

- To deploy only API and web, set values like:

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

- Then run `helm upgrade --install myrelease ./charts -f production-values.yaml`.

## Example: kustomize overlay to remove a component

- Base contains `deployment-web.yaml`, `deployment-api.yaml`, `deployment-worker.yaml`.
- Overlay `local` can remove `worker` via a `kustomization.yaml` that excludes or patches it out.

## Developer workflows

- Local dev (fast iteration):
	- Run backend locally (node/python) connecting to a local Postgres.
	- Start web app with dev server (e.g., Vite) and point to local API.
	- For Kubernetes parity, use `kind` or `minikube` with `skaffold` or `tilt` for live-reload.

- Full cluster testing:
	- Use `kind` + Helm to deploy overlays matching `staging`.

- Mobile development:
	- Use local simulators and a locally running API (expose via `ngrok` or via a local cluster ingress).

## CI/CD suggestions

- Pipeline stages:
	1. Lint, static analysis, unit tests
	2. Build artifacts (Docker images, mobile builds), tag
	3. Integration tests (on ephemeral cluster) — optional
	4. Publish images to registry
	5. Deploy via Helm (with chart-value toggles)

- Use ephemeral environments for PRs when feasible (Helm releases per-PR) and tear them down after merge.

## Observability & Security

- Include optional charts for Prometheus, Grafana, and OpenTelemetry. Provide an example `values.yaml` to enable them.
- Sentry is configured directly in the frontend application code, typically via build-time environment variables for the DSN.
- Use TLS via cert-manager for ingress.
- Recommend secrets stored in an external system (Vault) or use sealed-secrets for GitOps workflows.

## Example checklist for adding a new component

1. Add component folder under `packages/` with build/test scripts.
2. Add Helm chart or k8s manifest in `charts/` with `enabled` value.
3. Add CI step to build/test component when `enabled` or when relevant files change.
4. Document runtime env vars and config schema in `docs/`.

## Minimal validation & quality gates

- Unit tests and linters must pass.
- CI should run a helm template validation: `helm template` + `kubeval`/`conftest`.
- Optionally run an integration smoke test against a test cluster.

## Edge cases to consider

- Empty or null configuration values — charts should have sensible defaults.
- Large monorepo CI times — use smart CI that runs only changed packages.
- Secrets missing in production — fail fast and provide clear logs.
- Mobile API contract changes — version APIs and use backward-compatible changes.

## Next steps (how we can proceed)

1. Iterate the components list — adjust which components you want by default.
2. Add concrete Helm chart skeletons and kustomize bases.
3. Add CI pipeline examples (GitHub Actions) and a `kind`/`tilt` local workflow.
4. (Optional) Create a small skeleton repo with a simple API and web app to verify the end-to-end deploy.

If you'd like, I can now:

- expand any section above into a full `docs/` file,
- create example Helm chart templates guarded by `enabled` flags,
- scaffold a small skeleton `api` + `web` package and add CI workflow examples.

Please tell me which next step you'd like to tackle first.

## Chosen stack (summary)

- Frontend: Flutter for web, iOS, and Android, with Sentry for error reporting configured by default and Firebase for push notifications.
- Backend: Django as the recommended backend framework. Primary persistence: PostgreSQL via Django ORM. Configure which DB type to use via `DB_TYPE` env var or Helm `db.type` value.

Quick next-step options:

1. Scaffold `packages/flutter/` and a `packages/api/` Django project with Postgres configuration and migration placeholders.
2. Add Helm chart/value examples and a `k8s/` overlay to show toggling DB type and enabling/disabling frontend components.

If you'd like me to scaffold the Django project, tell me whether you prefer Django REST Framework (DRF) for APIs and whether you want Celery/Redis for background workers. I can start scaffolding that right away.

## Networking and Routing

The cluster uses an Ingress Controller to manage external traffic. This provides a powerful and flexible way to route requests to the correct services based on domain names or URL paths.

-   **Multi-Domain Strategy:** You can assign separate domains to different components. For example:
    -   `app.yourdomain.com` can route to the frontend web application.
    -   `api.yourdomain.com` can route to the backend API.
-   **Pluggable Technology:** The boilerplate is not tied to a single Ingress technology. You can choose the one that best fits your needs, such as:
    -   **NGINX Ingress Controller:** A popular and robust choice.
    -   **Traefik:** Known for its ease of use and automatic service discovery.
-   **TLS Termination:** The Ingress is the ideal place to handle TLS, terminating encrypted traffic before it reaches your services. This is typically managed by `cert-manager`, which can automatically provision SSL certificates.

