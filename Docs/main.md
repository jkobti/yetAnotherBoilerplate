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

Cross-platform clients share a Flutter codebase that targets web, iOS, and Android while leaning on shared design systems and API contracts. Keep the overview here high level; implementation details, optional integrations (Sentry, feature flags, push notifications, realtime clients, direct storage access), and platform-specific notes now live in `Docs/frontend.md`.

#### Admin Portal (Webapp)

In addition to end-user clients, the boilerplate includes a dedicated Admin Portal web application. Its purposes are:

- Display operational and business statistics/dashboards relevant to administrators.
- Trigger administrative actions that are explicitly restricted to admin users (e.g., feature toggles, job triggers, maintenance tasks).

Key notes:

- Access is strictly gated by authentication and role-based authorization; only users with the admin role can access the portal and invoke privileged endpoints.
- This portal is implemented as a webapp and deployed separately (distinct host or path), while reusing the shared design system where possible.
- Backend support includes admin-only API endpoints with auditing and rate limits; see `Docs/backend-api.md`.
- Deployment and routing guidance are covered in `Docs/k8s.md`.

## Kubernetes Operations Snapshot

Kubernetes remains the default runtime for every component. Use Helm value toggles, Kustomize overlays, environment-driven flags, and feature-flag services to enable or disable workloads per environment. Day-two operations—repository layout, deployment workflows, CI/CD expectations, observability stack, ingress patterns, and validation guardrails—are documented in `Docs/k8s.md`. Treat that guide as the source of truth when evolving platform automation or onboarding new components.

