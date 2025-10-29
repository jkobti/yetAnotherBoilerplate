## boiler — Project boilerplate documentation

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

## Components (required vs optional)

Core components (commonly required):

- Backend API: REST/GraphQL service (Node/Python/Go etc.)
- Database: PostgreSQL (primary example), with migrations
- Frontend Web App: single-page app (React/Vue/Svelte)
- CI/CD pipeline: build/test/publish and deploy to Kubernetes
- Kubernetes manifests / Helm charts: deployment, service, ingress, configmaps, secrets

Optional / recommended components:

- Mobile apps: iOS (Swift) and Android (Kotlin) — treat as separate apps but share API contracts
- Worker / background processors (e.g., queue consumers, cron jobs)
- Auth & identity: OAuth/OIDC integration or an Auth service (e.g., Keycloak, Auth0)
- Caching layer: Redis
- Object storage adapter: S3-compatible
- Observability: Prometheus, Grafana, OpenTelemetry tracing
- Logging: Fluentd/Fluent Bit or Loki
- Secrets management: external store (Vault, AWS Secrets Manager) or sealed-secrets
- Feature flags: LaunchDarkly or open-source alternatives

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

