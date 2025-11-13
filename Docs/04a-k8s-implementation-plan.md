# Kubernetes Cluster Implementation Plan

Companion to `04-k8s.md`. This document provides an actionable, phased execution roadmap for introducing Kubernetes to the monorepo. Treat each phase as incrementally shippable; avoid blocking later hardening on early experimentation.

---
## Current Progress Snapshot (Nov 13, 2025)
Status codes: ✅ complete • 🟡 partial • ⏳ pending • 💤 deferred

- Phase 0 (Baseline Assessment): ✅ Complete
  - Backend technology & image strategy decided (Python 3.11 slim + Poetry + gunicorn/uvicorn).
  - Naming & namespace conventions drafted (to be codified in initial manifests).
  - Image tagging approach (future: immutable SHA) noted.
- Phase 0.5 (Container Image Scaffolds): ✅ Complete (worker deferred)
  - Backend API Dockerfile implemented (multi-stage, non-root, entrypoint script for dynamic workers).
  - Customer & Admin Flutter web images implemented (builder → NGINX static) with shared `nginx.default.conf`.
  - JSON-driven build script (`docker_build_from_env_json.zsh`) supports local/prod config to build images reproducibly.
  - Service worker Firebase config injection script enhanced; successful embedding verified in both images.
  - `.dockerignore` added; monorepo path dependency (`ui_kit`) handled via root build context.
  - Worker image explicitly deferred (queue/system TBD).
- Phase 1 (Foundational Skeleton): ✅ Complete
  - `charts/api` scaffolded with Chart.yaml, values.yaml, deployment.yaml, service.yaml, _helpers.tpl.
  - All resources gated by `.Values.enabled` flag.
  - `k8s/base/namespaces.yaml` created with `apps`, `ingress`, `observability` namespaces.
  - Makefile targets added: `build-api`, `helm-template-api`, `kind-up`, `kind-down`, `deploy-local`.
  - `k8s/kind-config.yaml` configured with extraPortMappings (API 8000, web 8080, ingress 80/443).
  - Local kind cluster (`yab-local`) created and running.
  - API Helm chart deployed to `apps` namespace; pod healthy and passing readiness probes.
  - Health endpoint validated at `/health/` (trailing slash).
- Documentation: ✅ Backend & Flutter READMEs updated; `charts/api/README.md` with quick-start, parameters, examples, troubleshooting.
- Config Strategy: ✅ Build-time `--dart-define` + planned future runtime `config.js` (K8s ConfigMap).
- Security Hardening: ⏳ Not started (will begin with namespaces + service accounts in Phase 5).
- CI/CD: ⏳ Placeholder only (image build + helm lint pipeline not yet implemented).
- Observability: 💤 Deferred (after base charts & security).
- Web/Admin Charts: ⏳ Deferred until API chart validated locally (✅ validated); scaffold pattern ready to reuse.

Next Immediate Focus: Decide on web/admin chart scaffolding, then Phase 2 (Ingress & TLS) or Phase 3 (Observability) depending on priority.

---
## 0. Baseline Assessment
Purpose: establish starting point and naming conventions.

Tasks:
- Confirm absence/presence of `charts/` and `k8s/` directories; create if missing.
- Inventory container images to build: backend API, admin/web frontend, migrations (job). (Worker image deferred until queue system / task processor is finalized.)
- Decide naming conventions:
  - Release name prefix (e.g., `yab`)
  - Namespaces: `apps`, `ingress`, `observability`, `ops`
  - Label schema: `app.kubernetes.io/name`, `app.kubernetes.io/part-of=yetanotherboilerplate`, `app.kubernetes.io/component`
- Pick image tagging strategy (immutable SHA tags + semantic version alias).

Deliverables:
- Namespace manifest skeletons.
- Short naming cheat sheet in this doc appended after Phase 1.

---
## 0.5 Container Image Scaffolds (Parallel Track)
Purpose: produce repeatable, secure base images early to unblock local cluster tests, CI, and security scanning.

Images (initial set):
- Backend API (Python) — ASGI server (gunicorn + uvicorn worker assumed; adjust if different).
- Admin/Web frontend — Node build → NGINX (static) or Node runtime (SSR) (decide based on framework).
- Flutter web (optional) — only if shipping web build; builder (Flutter SDK) → NGINX static runtime.
- Migrations job — reuse backend image with different command (avoid duplicate image).

Deferred:
- Worker (Python background tasks) — will reuse backend base; to be added when queue/processing stack decided.

Design Guidelines:
1. Multi-stage builds: builder (dependencies, compile wheels) → slim runtime.
2. Immutable tagging: `sha-<GIT_SHA>` plus convenience tags (`edge`, semantic version for releases).
3. Non-root user (`app`) with explicit workdir (`/app`).
4. Layer caching: copy lock/config files before source.
5. Minimal attack surface: remove build tools from final stage; set `UMASK`, disable `pip` cache.
6. Health & metrics: leave probes to Kubernetes; avoid heavy baked-in health scripts early.

Directory Placement Options:
- Colocate: `packages/backend/Dockerfile`, `packages/backend/Dockerfile.worker`, `packages/flutter_app/Dockerfile.web`.
- Or centralized: `docker/backend/Dockerfile`, etc. (colocation preferred for context minimization).

Backend Dockerfile (Implemented Summary):
- Base: `python:3.11-slim`
- Builder stage installs Poetry + dependencies (using `poetry.lock`) and uvicorn.
- Runtime stage copies built environment, adds entrypoint script invoking gunicorn with uvicorn worker.
- Non-root `appuser` created; environment variables control `GUNICORN_WORKERS`, bind, module.
- Troubleshooting & persistence documented in backend README.

Tasks:
- Decide placement strategy (colocate vs central `docker/`).
- Create backend Dockerfile; migrations handled via same image + alt command.
- Create admin/web Dockerfile (static build → NGINX or Node runtime decision).
- (Optional) Create Flutter web Dockerfile if web distribution confirmed.
- Add `.dockerignore` (exclude tests, local env files, build artifacts).
- Add Make targets: `build-api`, `build-web`, `push-api`, `push-web` (later integrated into CI).
- Document environment variables required at runtime (`DATABASE_URL`, `REDIS_URL`, etc.).
- Record deferral note for worker image and criteria to implement (queue system chosen, scaling strategy defined).

Deliverables:
- Built local backend image runnable via `docker run` health endpoint check (✅ achieved).
- Built local images (web/admin) runnable (⏳ pending).
- Preliminary size metrics recorded (baseline for future optimization).
- Updated CI plan to include image build & vulnerability scan (Trivy stub).
- Worker image deferral documented (criteria + TODO).

---
## 1. Foundational Skeleton
Purpose: create minimal directory and chart scaffolds enabling opt-in components.

Directory Structure (target):
```
charts/
  api/
  web/
  admin/
  # worker/  (deferred)
k8s/
  base/
    namespaces.yaml
    network-policies/ (placeholder)
  overlays/
    local/
    staging/
    production/
```

Chart Minimum Files (per component):
- `Chart.yaml` (apiVersion v2, type application)
- `values.yaml` with `enabled`, image, replicaCount, resources, ingress block
- `templates/deployment.yaml` guarded by `{{- if .Values.enabled }}`
- `templates/service.yaml` guarded similarly
- `templates/ingress.yaml` (optional per component)

Deliverables:
- Empty scaffolds committed.
- Enabled flags validated via `helm template`.

---
## 2. Local Development (Inner Loop)
Purpose: fast iteration via local cluster parity.

Decisions:
- Local distro: `kind` (config committed as `k8s/kind-config.yaml`)
- Port mappings for web (e.g., 8080) and api (e.g., 8000)
- Optional dev tooling (Tilt or Skaffold) — defer if overhead.

Tasks:
- Write `kind-config.yaml` with extraPortMappings.
- Add `Makefile` targets: `kind-up`, `kind-down`, `deploy-local`.
- Document simple flow in README snippet.

Deliverables:
- Running local cluster with API chart installed.
- Access API ingress locally (host-based or port-forward fallback).

---
## 3. Ingress & TLS
Purpose: external routing & secure traffic.

Decisions:
- Ingress controller: NGINX
- TLS management: cert-manager (staging + production issuers)

Tasks:
- Add NGINX controller install instructions (Make target or Helm dependency notes).
- Create `ClusterIssuer` placeholders (`letsencrypt-staging`, `letsencrypt-prod`).
- Define ingress templates with host variables (`api.example.dev`, `app.example.dev`).
- For local: optional self-signed issuer.

Deliverables:
- Ingress manifests render with `helm template`.
- TLS ready for staging (may skip actual certificates until DNS set).

---
## 4. Observability Foundations
Purpose: metrics, dashboards, tracing readiness.

Decisions:
- Stack: kube-prometheus-stack (Prometheus + Grafana) in `observability` namespace.
- Tracing: OpenTelemetry Collector (deferred or placeholder chart).
- Logging: start with cluster logs; plan Loki/ELK later.

Tasks:
- Add `observability.enabled` global value.
- Provide Helm dependency notes / separate deployment instructions.
- Define basic alerts (API high error rate placeholder rule).

Deliverables:
- Metrics endpoints scraped (API pods expose `/metrics` if instrumented).
- Grafana accessible via protected ingress (optional early).

---
## 5. Security & Config Management
Purpose: least privilege & secret hygiene.

Tasks:
- Namespaces applied (`apps`, `ingress`, `observability`).
- ServiceAccounts per chart (api, worker) — future RBAC roles.
- Secret strategy: Kubernetes Secret for local/dev; plan SealedSecrets or external manager for staging/prod.
- NetworkPolicies: default deny in `apps`, allow from ingress namespace + observability scraping.
- LimitRanges & ResourceQuotas (prod overlay only).

Deliverables:
- Baseline NetworkPolicy objects in base (commented until enforced).
- Document secret naming convention (`api-env`, `worker-env`).

---
## 6. Autoscaling & Resilience
Purpose: predictable scaling behavior & safe rollouts.

Tasks:
- Add HPA templates (CPU target 70%) for API (worker autoscaling deferred).
- Liveness/readiness probes defaulted in Deployment template.
- PodDisruptionBudget (minAvailable: 1) for API (worker PDB deferred).
- Optional anti-affinity topology spread (commented examples).

Deliverables:
- `helm template` shows HPA & PDB only when enabled.
- Resource requests/limits baseline recorded in `values.yaml` (only API initially; worker to follow).

---
## 7. CI/CD Integration
Purpose: automated validation and deployment.

Pipeline Stages:
1. Lint & test (backend + frontend) + `helm lint`.
2. Build images, tag with SHA, push to registry.
3. `helm template` + `kubeval` (or `conftest` policies).
4. Ephemeral kind cluster deploy + smoke tests.
5. Deploy to staging with manual approval gate to production.

Tasks:
- Author workflow file (e.g., `.github/workflows/ci.yml`) with path filters for charts.
- Add caching (Docker layers, Python, Node) to speed builds.

Deliverables:
- Passing pipeline producing versioned images & validated manifests.

---
## 8. Progressive Delivery (Optional Early)
Purpose: controlled rollouts & canaries.

Tasks (Deferred unless required):
- Evaluate Argo Rollouts for blue/green or canary.
- Placeholder doc section referencing revisit criteria (traffic volume threshold).

Deliverables:
- Decision logged; if postponed, clear trigger conditions.

---
## 9. Documentation & Runbooks
Purpose: ensure maintainability & onboarding clarity.

Tasks:
- Link this file from `04-k8s.md` near "Next-Step Ideas".
- Add per-component README snippet: env vars, scaling levers, probes.
- Create `RUNBOOK_API.md` describing deploy, rollback, scale test.

Deliverables:
- Updated `04-k8s.md` referencing implementation plan.
- At least one runbook stub committed.

---
## 10. Risk & Edge Cases Tracking
Purpose: proactive mitigation.

Initial List:
- Missing secrets cause CrashLoop: implement startup log checks.
- Ingress DNS/TLS lag: fallback plan (HTTP only) documented.
- Over-scaling worker drains queue ordering: verify idempotency tests.
- CPU-based autoscaling ignoring latency: plan custom metric integration.
- Image tag drift (latest): enforce immutable SHA + retention policy.

Tasks:
- Add `RISK_REGISTER.md` in `Docs/` or append to this file.
- Flag each risk with severity & mitigation status.

Deliverables:
- Initial risk register committed.

---
## Execution Order (Recommended Sprint Flow)
1. ✅ Phases 0 & 0.5 (baseline + container images) — complete.
2. ✅ Phase 1 chart skeletons referencing image tags — complete; API chart deployed locally.
3. ✅ Phase 2 local cluster — kind cluster created and operational.
4. ⏳ Phase 3 ingress/TLS scaffolding (next priority if external access needed).
5. ⏳ Phase 5 security basics (namespaces ✅ created; service accounts + RBAC pending).
6. ⏳ Phase 6 autoscaling templates (disabled by default; ready to enable).
7. ⏳ Phase 7 CI pipeline baseline (image build + manifest validation + smoke tests).
8. ⏳ Phase 4 observability (enabled after base stable & security pass).
9. ⏳ Phase 9 docs & runbooks.
10. ⏳ Phase 10 risk register formalization.

Current State: Phase 1 MVP achieved locally. Next decision point: Phase 2 (ingress) or Phase 7 (CI) or scaffold web/admin charts.

---
## Minimal Helm values Example (API)
```yaml
api:
  enabled: true
  image:
    repository: ghcr.io/yourorg/api
    tag: "sha-<gitsha>"
    pullPolicy: IfNotPresent
  replicaCount: 2
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  ingress:
    enabled: true
    host: api.local.dev
    path: /
    className: nginx
    tls: false
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 6
    targetCPUUtilizationPercentage: 70
```

---
## Naming Cheat Sheet
| Item               | Convention       | Example                            |
| ------------------ | ---------------- | ---------------------------------- |
| Namespace          | logical grouping | `apps`, `ingress`, `observability` |
| Release name       | chart purpose    | `yab-api`, `yab-web`               |
| Labels             | k8s recommended  | `app.kubernetes.io/name=api`       |
| Secrets            | component-env    | `api-env`, `worker-env`            |
| ConfigMaps         | component-config | `api-config`                       |
| Ingress host (dev) | subdomain local  | `api.local.dev`                    |

---
## Future Enhancements (Not in MVP)
- Service Mesh (Istio/Linkerd) for mTLS & traffic metrics.
- Canary rollouts (Argo Rollouts) integrated with metrics provider.
- Centralized tracing (OTLP collector + backend).
- Log aggregation (Loki or OpenSearch stack).
- Policy enforcement (OPA Gatekeeper) for org standards.

---
## Completion Criteria for MVP
- ✅ API chart deploys locally via kind (chart scaffolded, deployed, pod healthy).
- ✅ Health endpoint responds correctly (`/health/` returns 200 OK).
- ⏳ Ingress routes traffic to API (pending Phase 2 implementation).
- ⏳ CI builds & templates charts with no validation errors (pending Phase 7).
- ✅ Security basics: namespaces created + ready for service accounts.
- ✅ Documentation links in place (this file updated; chart README complete).
- ✅ Backend API image builds successfully (non-root, multi-stage) and runs health endpoint.
- ✅ Worker image explicitly deferred with documented criteria for introduction.

Phase 1 MVP Achievement:
- ✅ Helm chart structure proven locally.
- ✅ kind cluster operational with port mappings.
- ✅ API pod deployed and healthy.
- ✅ Pattern established for web/admin chart reuse.

Delta Remaining for Full MVP:
1. ⏳ Enable Ingress & test external routing (Phase 2).
2. ⏳ Add basic observability scaffolding if prioritized (Phase 4).
3. ⏳ Integrate image build + helm lint into CI pipeline (Phase 7).
4. ⏳ Scaffold web/admin charts following API pattern (Phase 1 extension).

---
Maintain this file as a living roadmap; update phase statuses inline or move completed phases to a changelog section at the bottom if preferred.
