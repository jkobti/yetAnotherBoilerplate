
Root Project Structure
This top-level organizes the project by function: platform (charts, k8s), application code (packages), and project support (docs, .github).
```
/yetAnotherBoilerplate/
├── .github/              # CI/CD workflows (GitHub Actions)
│   └── workflows/
│       ├── ci.yml        # Main build/test pipeline (path-based)
│       └── deploy.yml    # Helm-based releases
├── .gitignore            #
├── README.md             # Your "work in progress" file
├── docker-compose.yml    # For local dev (Postgres, Redis, etc.)
├── Makefile              # Helper scripts (e.g., `make local-dev`, `make build`)
│
├── charts/               # Helm charts for each component
│   ├── backend/
│   ├── frontend-customer/
│   └── frontend-admin/
│
├── docs/                 # All your provided documentation
│   ├── backend-api.md    #
│   ├── components-overview.md #
│   ├── frontend.md       #
│   ├── k8s.md            #
│   └── main.md           #
│
├── k8s/                  # Base Kustomize manifests (if needed)
│
└── packages/             # The monorepo home for all application code
    │
    ├── backend/          # (See Backend Structure)
    ├── flutter_app/      # (See Frontend Structure)
    └── ui_kit/           # (See Shared UI Kit Structure)
```
1. Backend Package (packages/backend/)
This package now contains everything for your Django backend, including the build files for both the API server and the Celery worker.
```
/packages/backend/
├── .dockerignore
├── Dockerfile            <-- Builds the API server (runs Gunicorn)
├── Dockerfile.worker     <-- Builds the Worker (runs Celery)
│
├── manage.py
├── pyproject.toml        # Poetry-managed dependencies and project metadata
├── poetry.lock           # Locked dependency versions for reproducible builds
├── celery_app.py         # Celery app definition (finds tasks)
│
├── boilerplate/            # Your main Django project (rename as needed)
│   ├── __init__.py
│   ├── asgi.py             # For Django Channels (WebSockets)
│   ├── settings.py         # Main settings (Anymail, DRF, etc.)
│   ├── urls.py             # Root URL router
│   │   # Defines /api/v1/app/, /api/v1/admin/, /api/v1/public/
│   │   # Includes toggle for drf-spectacular docs
│   └── wsgi.py
│
└── apps/                   # All your Django apps
    ├── __init__.py
    ├── users/              # For your CustomUser model
    │   ├── models.py
    │   └── tasks.py        # Example worker tasks (e.g., send_welcome_email)
    │
    ├── organizations/      # For Organization & Membership
    │   └── models.py
    │
    ├── public_api/         # For APIKey model & public endpoints
    │   ├── models.py
    │   ├── views.py
    │   └── ...
    │
    ├── notifications/      # For the Notification model
    │   └── models.py
    │
    └── admin_api/          # Endpoints for your Admin Portal
        ├── views.py
    └── ...
```
2. Frontend Package (packages/flutter_app/)
This single Flutter project builds both your Customer and Admin apps by using two different entry points (main.dart and main_admin.dart).
```
/packages/flutter_app/
├── .dockerignore
├── Dockerfile.web          # Builds NGINX container for Customer App
├── Dockerfile.admin.web    # Builds NGINX container for Admin Portal
│
├── android/                # Android platform wrapper
├── ios/                    # iOS platform wrapper
├── web/                    # Web platform wrapper
│
├── lib/
│   ├── main.dart           <-- 1. Entry point for Customer App
│   ├── main_admin.dart     <-- 2. Entry point for Admin App
│   │
│   ├── core/               # Shared services for both apps
│   │   ├── api_client.dart # Generated OpenAPI client (dio)
│   │   └── router.dart     # go_router configuration
│   │
│   ├── features_customer/  # Screens & logic for the Customer App
│   │   ├── auth/           # Login/logout flow
│   │   └── home/
│   │
│   └── features_admin/     # Screens & logic for the Admin App
│       ├── auth/           # Admin login flow
│       └── dashboard/      # Metrics and stats
│
└── pubspec.yaml            # Manages all dependencies (Riverpod, dio, etc.)
    # ...
    # dependencies:
    #   ui_kit:
    #     path: ../ui_kit    <-- Imports the shared UI Kit
```
3. Shared UI Kit (packages/ui_kit/)
This is a local Flutter library that packages/flutter_app depends on. It fulfills your requirement to have a shared design system.
```
/packages/ui_kit/
├── lib/
│   ├── src/
│   │   ├── widgets/      # e.g., PrimaryButton, DataCard, StyledTextField
│   │   └── theme.dart    # Shared colors, typography, spacing
│   │
│   └── ui_kit.dart       # Exports all public components/themes
│
└── pubspec.yaml            # This file makes it a "package"
```