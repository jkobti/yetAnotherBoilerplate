# Component Coverage Overview

This sheet summarizes the major components included in the boiler project and highlights the features that are enabled by default versus those that are optional. Consult the linked documents for implementation details and configuration steps.

## Platform & Cluster Services

| Layer    | Component                                                                       | Default    | Supported Features                                                                     | Reference     |
| :------- | :------------------------------------------------------------------------------ | :--------- | :------------------------------------------------------------------------------------- | :------------ |
| Platform | Kubernetes base resources (Deployments, Services, Ingress, ConfigMaps, Secrets) | ✅          | Baseline runtime primitives for every workload.                                        | `Docs/k8s.md` |
| Platform | CI/CD pipeline                                                                  | ✅          | Automated build, test, and deploy stages; artifact publishing; Helm-based releases.    | `Docs/k8s.md` |
| Platform | PostgreSQL (stateful service)                                                   | ⚙️ Optional | Cluster-managed Postgres for transactional storage when an external DB is unavailable. | `Docs/k8s.md` |
| Platform | Redis (cache / Celery broker)                                                   | ⚙️ Optional | In-memory caching and message brokering for workers and realtime layers.               | `Docs/k8s.md` |
| Platform | Logging stack (Loki / Fluentd)                                                  | ⚙️ Optional | Centralized log aggregation with searchable retention.                                 | `Docs/k8s.md` |
| Platform | Observability stack (Prometheus, Grafana, OpenTelemetry collector)              | ⚙️ Optional | Metrics, dashboards, tracing export pipeline.                                          | `Docs/k8s.md` |
| Platform | Authentication (Keycloak)                                                       | ⚙️ Optional | Self-hosted identity provider for SSO/OIDC flows.                                      | `Docs/k8s.md` |
| Platform | Secrets management (Sealed Secrets / Vault)                                     | ⚙️ Optional | GitOps-friendly or centralized secret storage.                                         | `Docs/k8s.md` |
| Platform | Object storage (S3-compatible / MinIO)                                          | ⚙️ Optional | Binary asset storage for uploads, static media, CDN sources.                           | `Docs/k8s.md` |
| Platform | Ingress controller (NGINX/Traefik) + cert-manager                               | ✅          | Host/path routing plus TLS/mTLS certificates for secure component auth.                | `Docs/k8s.md` |

## Backend Application Stack

| Area               | Feature                                                     | Default    | Notes                                                          | Reference             |
| :----------------- | :---------------------------------------------------------- | :--------- | :------------------------------------------------------------- | :-------------------- |
| API service        | Django + DRF                                                | ✅          | Primary REST/GraphQL endpoint.                                 | `Docs/backend-api.md` |
| Persistence        | PostgreSQL via Django ORM                                   | ✅          | Primary relational datastore.                                  | `Docs/backend-api.md` |
| Schema management  | Django migrations                                           | ✅          | Code-driven schema evolution.                                  | `Docs/backend-api.md` |
| API protection     | Rate limiting                                               | ✅          | Sensible global throttles; configurable per view.              | `Docs/backend-api.md` |
| Communication      | Email integration via Django-Anymail                        | ✅          | Provider-agnostic transactional email.                         | `Docs/backend-api.md` |
| Documentation      | drf-spectacular + ReDoc                                     | ✅          | OpenAPI 3.0 generation and docs UX.                            | `Docs/backend-api.md` |
| API design         | Customer-facing API template                                | ✅          | Opinionated versioning, pagination, errors, idempotency keys.  | `Docs/backend-api.md` |
| Background jobs    | Celery workers (Redis/RabbitMQ)                             | ⚙️ Optional | Asynchronous task execution, scheduled jobs.                   | `Docs/backend-api.md` |
| Realtime           | Django Channels (WebSockets)                                | ⚙️ Optional | Live notifications, chat, collaborative experiences.           | `Docs/backend-api.md` |
| Storage            | S3-compatible integration via django-storages               | ⚙️ Optional | Presigned uploads/downloads, asset offloading.                 | `Docs/backend-api.md` |
| Auth               | OAuth/OIDC integrations                                     | ⚙️ Optional | External identity providers (Keycloak, Auth0, Google, GitHub). | `Docs/backend-api.md` |
| Feature management | Feature flag services (LaunchDarkly, Unleash, django-flags) | ⚙️ Optional | Runtime gating of backend features.                            | `Docs/backend-api.md` |

## Frontend (Web, iOS, Android)

| Area               | Feature                                      | Default    | Notes                                                   | Reference          |
| :----------------- | :------------------------------------------- | :--------- | :------------------------------------------------------ | :----------------- |
| Framework          | Flutter (shared codebase)                    | ✅          | Targets web, iOS, and Android from a single repository. | `Docs/frontend.md` |
| State              | Riverpod or Bloc                             | ✅          | Choose once per project; examples assume Riverpod.      | `Docs/frontend.md` |
| API client         | `dio` with generated OpenAPI clients         | ✅          | Aligns with backend OpenAPI schema.                     | `Docs/frontend.md` |
| Design system      | Shared component library (`packages/ui/`)    | ✅          | Consistent theming, typography, spacing.                | `Docs/frontend.md` |
| Routing            | `go_router`                                  | ✅          | Declarative navigation with deep link support.          | `Docs/frontend.md` |
| Error reporting    | Sentry (`sentry_flutter`)                    | ⚙️ Optional | Enabled via `FRONTEND_SENTRY_DSN`.                      | `Docs/frontend.md` |
| Auth flows         | Login/logout/MFA UI                          | ⚙️ Optional | Mirrors backend auth endpoints; feature flagged.        | `Docs/frontend.md` |
| Feature flags      | Unleash proxy client                         | ⚙️ Optional | Enables remote controlled UI toggles.                   | `Docs/frontend.md` |
| Push notifications | Firebase Cloud Messaging (wraps APNs on iOS) | ⚙️ Optional | Controlled by `PUSH_NOTIFICATIONS_ENABLED`.             | `Docs/frontend.md` |
| Realtime           | WebSocket/STOMP client                       | ⚙️ Optional | Connects to backend Channels endpoints.                 | `Docs/frontend.md` |
| Storage            | Direct object storage access                 | ⚙️ Optional | Uses pre-signed URLs for uploads/downloads.             | `Docs/frontend.md` |

## Quick Legend

- ✅ Default: included out-of-the-box when the boilerplate is instantiated.
- ⚙️ Optional: available patterns that can be toggled on via Helm values, environment variables, or feature flags.

Keep this sheet in sync when new components are introduced or when defaults change. Update the linked documents with deeper guidance as part of the same change.

## Admin Portal (Webapp)

| Area     | Component             | Default | Notes                                                                                   | Reference                                 |
| :------- | :-------------------- | :------ | :-------------------------------------------------------------------------------------- | :---------------------------------------- |
| Frontend | Admin Portal (webapp) | ✅       | Web-only admin UI to display statistics and trigger admin-only actions (RBAC enforced). | `Docs/frontend.md`, `Docs/backend-api.md` |

Purpose and scope:

- Present operational/business statistics to administrators.
- Allow triggering privileged actions (e.g., feature toggles, job triggers, maintenance tasks) that are forbidden to non-admins.
- Backend endpoints must require admin authorization and should be audited; see `Docs/backend-api.md`.
- Deployment, routing, and access controls are covered in `Docs/k8s.md`.
