# Backend API Service

This document defines the core requirements, features, and architectural decisions for the primary API service (`packages/backend/`), built using Django and Django REST Framework (DRF). The service is designed for modularity, high developer experience, and production readiness.

---

## 1. Core Technical Stack

| Area                  | Component                         | Note                                                                                           |
| :-------------------- | :-------------------------------- | :--------------------------------------------------------------------------------------------- |
| **Framework**         | Django                            | Recommended backend framework.                                                                 |
| **API**               | Django REST Framework (DRF)       | Standard for building REST APIs on Django.                                                     |
| **Database**          | PostgreSQL                        | Primary persistence layer, managed via Django ORM.                                             |
| **Documentation**     | **`drf-spectacular`** + **ReDoc** | Automatic OpenAPI 3.0 generation paired with a modern rendering UI.                            |
| **Dependencies**      | Poetry                            | Manage deps in `pyproject.toml`; lock with `poetry.lock`. Use `poetry add` / `poetry install`. |
| **Local Development** | Poetry                            | See `packages/backend/README.md` for setup and run instructions.                               |

---

## 1.1 Local development

See `packages/backend/README.md` for local setup, environment variables, and run commands.

### JWT authentication (for frontend apps)

Endpoints (JSON):

- Obtain tokens: `POST /api/auth/jwt/token/` → `{ "access": "...", "refresh": "..." }`
- Refresh access: `POST /api/auth/jwt/refresh/` → `{ "access": "..." }`
- Verify token: `POST /api/auth/jwt/verify/`

Notes:
- Send `Authorization: Bearer <access>` to call protected endpoints like `/api/v1/me`.
- Credentials fields match the user model: `{ "email": "user@example.com", "password": "..." }`.
- Token lifetimes (defaults): access 15 minutes, refresh 30 days.

Examples:

```http
POST /api/auth/jwt/token/
Content-Type: application/json

{"email":"admin@example.com","password":"<your password>"}
```

```http
GET /api/v1/me
Authorization: Bearer <access>
```

## 1.2 Background Tasks (Celery)

The project includes a Celery setup for asynchronous background processing, backed by Redis.

- **Configuration**: `packages/backend/boilerplate/celery.py`
- **Tasks**: Define tasks in `tasks.py` within each app (e.g., `packages/backend/apps/public_api/tasks.py`).
- **Triggering**: Use `.delay()` or `.apply_async()` on the task function.

### Example Task

```python
# apps/public_api/tasks.py
from celery import shared_task

@shared_task
def sample_background_task(user_email):
    # ... long running process ...
    pass
```

### Running Locally

1.  Start Redis (e.g., `docker run -p 6379:6379 redis`).
2.  Start the worker:
    ```zsh
    poetry run celery -A boilerplate worker -l info
    ```

### Kubernetes Deployment

The worker is deployed as a separate deployment using the same Docker image as the API. It is disabled by default.

To enable it:
1.  Deploy Redis: `make deploy-redis`
2.  Enable Worker: `make deploy-worker`

See `Docs/k8s.md` for more details.

---

## 2. Core Backend Feature Requirements

These features are essential for a production-ready application and should be configured and enabled by default in the API service.

- **API Service:** Acts as the central REST/GraphQL endpoint for all clients (Web, iOS, Android).
- **Database Migrations:** Schema changes must be managed through code using the Django ORM's migration system.
- **API Rate Limiting:** A default, sensible rate-limiting policy must be configured globally to prevent abuse.
- **Email Integration:** Configured to support transactional email via **Django-Anymail**. Provider selection (e.g., Resend, Postmark, SendGrid) must be handled entirely through environment variables, requiring no code changes.

---

## 3. Identity, Tenancy, and Supporting Models

Establish these base models early. They unlock flexibility (custom fields), secure multi-tenancy, and production-grade integrations (API access, notifications). Names and apps are suggestions; align with your repo layout.

### 3.1 The Core Identity: User

- Do not use Django's built-in `User` model directly. Start with a CustomUser that inherits from `AbstractUser`.
- App: `users`
- Model: `User` (extends `AbstractUser`)

Key fields and choices:

- `id`: UUID primary key (recommended for security and scalability)
- `email`: make this the primary username field (`USERNAME_FIELD = "email"`), unique and indexed
- `first_name`, `last_name`
- `is_staff`: admin-access flag for the Admin Portal
- `date_joined`, `last_login` (from `AbstractUser`)
- Room for future fields without painful migrations: `avatar_url`, `phone_number`, etc.

Why: Choosing CustomUser up front avoids brittle migrations later and gives you control over auth shape and identifiers.

### 3.2 The Core Tenancy: Organization & Membership

Assume multi-tenancy from day one. Users belong to one or more organizations (aka teams/workspaces). This pattern scales from B2B (companies) to consumer (family plan / project workspace).

A) Organization

- App: `organizations`
- Model: `Organization`

Key fields:

- `id`: UUID
- `name`: e.g., "Acme Inc."
- `owner`: FK → `users.User` (the creator/primary admin)
- `members`: ManyToMany → `users.User` via `Membership` (through model)

B) Membership (through model)

- App: `organizations`
- Model: `Membership`

Key fields:

- `id`
- `user`: FK → `users.User`
- `organization`: FK → `organizations.Organization`
- `role`: CharField with choices (e.g., `admin`, `member`, `billing`)

Critical rule: Domain data (projects, documents, subscriptions, etc.) should belong to an `Organization`, not a `User`. Query and permission checks must always scope by tenant.

### 3.3 Core Supporting Models (API access and notifications)

A) APIKey

- App: `api` (or `public_api`)
- Model: `APIKey`

Key fields:

- `id`
- `key_prefix`: short display-safe prefix (e.g., `sk_live_...`)
- `hashed_key`: store a hash only; never the raw key
- `organization`: FK → `organizations.Organization` (keys belong to the team)
- `last_used`
- `expires_at`

Notes:

- Rotate keys, capture minimal audit (who created, when, last_used IP if applicable), and consider scopes if you expose granular permissions.

B) Notification

- App: `notifications`
- Model: `Notification`

Key fields:

- `id`
- `recipient`: FK → `users.User`
- `message`: human-readable text (e.g., "Jane commented on your post.")
- `type`: enumerated type (e.g., `new_comment`, `billing_alert`)
- `read_at`: timestamp (null if unread)
- `target_url`: deep-link to view in app

Notes:

- Backends can fan out realtime via Channels/WebSockets, queue push notifications (FCM/APNs), and expose REST for notification lists and read-state toggles.

### Summary: Base Data Model

Adopt these models for a batteries-included foundation:

- `User` (Custom, UUID PK, email as username)
- `Organization` (tenant)
- `Membership` (through model with role)
- `APIKey` (tenant-scoped customer API access)
- `Notification` (user communications, realtime-friendly)

These provide identity, multi-tenancy, API access, and user communication with minimal friction and align with customer-facing API and frontend notification patterns described elsewhere in this boilerplate.

## 4. API Documentation Strategy: `drf-spectacular` + ReDoc

To deliver high-quality, auto-generated, and visually impressive documentation, the following strategy will be used:

### A. Automatic Schema Generation

- **Tool:** **`drf-spectacular`**
- **Function:** Automatically introspects your Django REST Framework code (Views, Serializers, ViewSets, URL patterns) to generate an accurate, up-to-spec **OpenAPI 3.0** JSON/YAML file.
- **Benefit:** Ensures the documentation stays synchronized with the code, eliminating manual documentation maintenance overhead.

### B. Documentation Presentation

- **Renderer:** **ReDoc**
- **Function:** Uses the OpenAPI file generated by `drf-spectacular` to render the interactive, single-page, three-panel reference documentation.
- **Goal:** Provides a superior aesthetic and user experience compared to the default Swagger UI.

### C. Implementation Overview

1. **Installation:** Install `drf-spectacular` in the backend project.
2. **Configuration:** Add `drf_spectacular` to `INSTALLED_APPS` and configure metadata (title, version) in `settings.py`.
3. **URL Setup:** Add the following endpoints to your main `urls.py`:
   - **Schema Endpoint:** An endpoint to serve the raw OpenAPI JSON file (e.g., `/api/schema/`).
   - **ReDoc UI Endpoint:** An endpoint that loads the ReDoc template, pointing it to the schema (e.g., `/api/docs/`).

### D. Activation / Deactivation Strategy

Following the project's modularity principle, documentation endpoints should be easy to disable in production environments where they might expose internal information or consume resources.

1. **Environment Variable Toggle:** Use an environment variable, such as `API_DOCS_ENABLED`, to control the URL inclusion.

   ```python
   # packages/api/urls.py (Conceptual)
   from django.urls import path, include
   from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView
   import os

   urlpatterns = [
       # ... other API routes ...
   ]

   if os.environ.get('API_DOCS_ENABLED', 'False').lower() == 'true':
       urlpatterns += [
           # The URL to the raw OpenAPI schema (used by the frontend)
           path('api/schema/', SpectacularAPIView.as_view(), name='schema'),

           # The URL to the beautiful ReDoc UI
           path('api/docs/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
       ]
   ```

2. **Helm Value Guard (Recommended for Kubernetes):** In your `charts/api/values.yaml`, define a toggle:

   ```yaml
   # charts/api/values.yaml
   api:
       # ... other config ...
       docs:
           enabled: true
           # This env var will be passed to the API container
           env_var: "API_DOCS_ENABLED"
   ```

   You would then inject this as an environment variable into the API Deployment manifest, ensuring documentation is only available when explicitly enabled via Helm values.

---

## 5. Optional Backend Features

These features can be enabled based on project requirements:

### 5.1 Worker Processes (Celery)

**Purpose:** Running background jobs asynchronously (e.g., sending emails, processing uploads, generating reports).

**Technology:** Celery with Redis or RabbitMQ as the message broker.

**Use Cases:**
- Sending emails asynchronously to avoid blocking API responses.
- Processing file uploads (image resizing, document parsing).
- Scheduled tasks (daily reports, cleanup jobs).

**Activation Strategy:**
- Enable via Helm values: `worker.enabled: true`
- Deploy as a separate Kubernetes Deployment.

### 5.2 Real-time Communication (WebSockets)

**Purpose:** Persistent, bidirectional connections for live updates.

**Technology:** Django Channels with Redis channel layer.

**Use Cases:**
- Live notifications
- Chat applications
- Collaborative editing
- Real-time dashboards

**Activation Strategy:**
- Enable via feature flag: `WEBSOCKETS_ENABLED=true`
- Deploy WebSocket server as separate service (can share codebase with API).

### 5.3 Object Storage Integration

**Purpose:** Storing and serving user-uploaded files (images, documents, videos).

**Technology:** S3-compatible storage (AWS S3, MinIO, DigitalOcean Spaces).

**Implementation:** Use `django-storages` with boto3.

**Best Practice:** Generate pre-signed URLs for direct client uploads/downloads to reduce server load.

**Service Authentication:** Require TLS everywhere. Issue service certificates via cluster cert-manager so frontend-to-backend traffic (including WebSockets) uses mTLS when deployed inside the cluster or through the ingress.

### 5.4 Authentication & Authorization

**Options:**
1. **Django's built-in auth** + JWT tokens (via `djangorestframework-simplejwt`)
2. **OAuth2/OIDC** integration with external providers (Keycloak, Auth0, Google, GitHub)
3. **Social authentication** via `django-allauth`

**Recommendation:** Start with JWT tokens for API authentication, add OAuth2 integration as needed.

### 5.5 Feature Flag Integration

**Purpose:** Toggle features at runtime without code deployments.

**Options:**
- **LaunchDarkly** (commercial)
- **Unleash** (open-source)
- **Django-flags** (simple, database-backed)

**Use Cases:**
- Gradual feature rollout
- A/B testing
- Emergency feature disable

---

## 6. Customer-Facing API Template

Provide a built-in, opinionated template for customer-facing API endpoints to ensure consistency, stability, and excellent developer experience.

Contract guidelines:

- Versioning: prefix routes with a version (e.g., `/api/v1/...`) and avoid breaking changes within a major version.
- Authentication: support API keys and/or OAuth2 (client credentials) for service integrations; JWT for first-party apps.
- Pagination: cursor- or page-based pagination with standard query params and response metadata (`next`, `prev`, `total` when applicable).
- Filtering & sorting: predictable query parameters (`filter[field]=`, `sort=field,-other`) with documented allowlists.
- Errors: structured errors using RFC 7807 Problem Details or a consistent envelope with machine-readable codes.
- Idempotency: support an `Idempotency-Key` header for safe retries on POST/PUT operations.
- Rate limiting: include standard headers (e.g., `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After`).

Example shapes (illustrative):

```http
GET /api/v1/customers?cursor=eyJvZmZzZXQiOjEwMH0=&filter[status]=active&sort=-created_at
Authorization: Bearer <token>
```

```json
{
    "data": [ { "id": "cust_123", "email": "a@example.com", "status": "active" } ],
    "meta": { "next": "eyJvZmZzZXQiOjIwMH0=", "prev": null, "total": 1024 }
}
```

```http
POST /api/v1/invoices
Idempotency-Key: 7ad2b6c1-0e6f-4ac3-9c0a-1a2b3c4d5e6f
Content-Type: application/json

{"customer_id":"cust_123","items":[{"sku":"sku_1","qty":2}]}
```

```json
{
    "id": "inv_789",
    "status": "pending",
    "created_at": "2025-11-01T10:00:00Z"
}
```

OpenAPI documentation:

- Provide reusable components (schemas, parameters, responses) for pagination, errors, and common headers.
- Tag endpoints by domain (e.g., Customers, Invoices) and include example requests/responses.

Security & multi-tenancy:

- Enforce tenant scoping at the data layer and in queries.
- Log sensitive operations and surface correlation IDs for support.

Refer to this template when adding new public/customer endpoints to keep APIs consistent and easy to integrate.

## 7. Admin Endpoints & RBAC

Admin functionality must be exposed via dedicated, restricted API endpoints consumed by the Admin Portal webapp.

Requirements:

- Authorization: enforce admin-only access via RBAC (e.g., Django groups/permissions or role claims in JWT/OIDC tokens). Deny by default.
- Auditing: record who invoked an admin action, when, and with what parameters and outcome. Store audit logs in an append-only fashion where feasible.
- Rate limiting: by default, user-facing endpoints are throttled globally (Anon/User). Admin endpoints are NOT throttled by default to avoid impeding internal workflows. If desired, you can enable per-view throttles on admin endpoints using DRF's ScopedRateThrottle (e.g., `throttle_scope = "admin"`) and configure a rate under `REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]`.
- Idempotency and safety: design write endpoints to be idempotent where possible; prefer explicit, narrowly scoped operations over generic commands.
- CSRF and headers: for browser-based flows, ensure CSRF protection and strict security headers when accessed via the admin host/path.

Example endpoint categories (illustrative):

- Metrics & summaries: `/admin/metrics/...` for high-level stats surfaced in the portal.
- Job control: `/admin/jobs/...` to enqueue maintenance tasks or retries subject to permission checks.
- Feature management: `/admin/features/...` to toggle or configure feature flags in a controlled way.

Document and version admin endpoints alongside the public API, but host them under a separate URL namespace to simplify firewalling and routing.

### Magic Link Authentication (Passwordless Email Code)

The API supports passwordless login/sign-up via a short 8-digit code delivered by email. A code is generated, stored hashed, emailed to the user, and then verified to issue JWT tokens. The email also contains a direct link to the frontend verify page with `?token=...` appended for convenience, plus the raw code for manual entry.

Endpoints:
- `POST /api/auth/magic/request/` body: `{"email": "user@example.com"}` → `202 Accepted` (may include `debug_token` when `DEBUG` and `MAGIC_LINK_DEBUG_ECHO_TOKEN` are enabled)
- `POST /api/auth/magic/verify/` body: `{"token": "12345678"}` → `200 OK` with `{ access, refresh, user }` or `400 {"error": "invalid_or_expired"}`

Environment Variables:
- `MAGIC_LINK_VERIFY_URL` (REQUIRED outside isolated unit tests) Absolute frontend origin or full verify page URL. Must start with `http://` or `https://`.
    - Ends with `/magic-verify` → backend appends `?token=...`
    - Base origin only (`https://app.example.com`) → backend appends `/magic-verify?token=...`
    - Missing or non-HTTP(S) value raises `RuntimeError` when sending email.
- `MAGIC_LINK_EXPIRY_MINUTES` (default 15) Code lifespan.
- `MAGIC_LINK_DEBUG_ECHO_TOKEN` (DEV ONLY) Echo raw code in API response when requesting; never enable in prod.

Operational Notes:
1. Codes single-use; reuse fails with `invalid_or_expired`.
2. Codes hashed (SHA256) at rest.
3. Email provider via Django-Anymail; `EMAIL_PROVIDER=console` prints emails to stdout only.
4. Tests must set `settings.MAGIC_LINK_VERIFY_URL` due to enforcement.

Troubleshooting:
- RuntimeError complaining about unset verify URL → Set `MAGIC_LINK_VERIFY_URL` (e.g. `http://localhost:5173`).
- Seeing `x-webdoc://` or other odd scheme → Artifact of copying from a local preview/console backend; proper absolute URL removes fallback so this no longer occurs.
- No email delivered while on console provider → Switch to `EMAIL_PROVIDER=resend` and set `RESEND_API_KEY`.
- Manual verification needed → User enters 8-digit code directly on verify page.

Security:
- Short expiry (≤15 minutes) recommended.
- Disable debug echo outside local.
- Add a DRF scoped throttle (e.g. `magic`) to mitigate brute-force; plan for future rate config (e.g. `REST_FRAMEWORK['DEFAULT_THROTTLE_RATES']['magic'] = '5/min'`).

Future Enhancements:
- Cleanup cron/command for expired codes.
- HTML branded email template.
- Track last successful magic code login timestamp.

## 8. References

- [Django Documentation](https://docs.djangoproject.com/)
- [Django REST Framework](https://www.django-rest-framework.org/)
- [drf-spectacular Documentation](https://drf-spectacular.readthedocs.io/)
- [ReDoc](https://redocly.com/redoc)
- [Django-Anymail](https://anymail.dev/)
- [Celery Documentation](https://docs.celeryq.dev/)
- [Django Channels](https://channels.readthedocs.io/)
