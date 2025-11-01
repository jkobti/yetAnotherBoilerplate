# Backend service (Django)

This package contains the Django backend for yetAnotherBoilerplate.

- Dependencies are managed with Poetry via `pyproject.toml` and `poetry.lock`.
- Local development defaults to SQLite; set `DATABASE_URL` to use Postgres.
- Custom user model uses email as the username (UUID primary key).

## Prerequisites

- Python 3.11
- Poetry (install via Homebrew or pipx)

## Quickstart (local, no Kubernetes)

```zsh
cd packages/backend

# Use Python 3.11 and install dependencies
poetry env use 3.11
poetry install

# Create a local env file (edit values as needed)
cp -n .env.example .env || true

# Run migrations and create an admin user
poetry run python manage.py makemigrations
poetry run python manage.py migrate
poetry run python manage.py createsuperuser --email admin@example.com

# Start the dev server
poetry run python manage.py runserver 0.0.0.0:8000
```

Endpoints (dev defaults):

- Health: http://localhost:8000/health/
- Admin: http://localhost:8000/admin/
- API docs (if `API_DOCS_ENABLED=true`): http://localhost:8000/api/docs/
- Root `/` redirects to `/api/docs/` when docs are enabled; otherwise it serves the health endpoint.

## JWT authentication

Endpoints:

- Obtain tokens: `POST /api/auth/jwt/token/` → `{ "access": "...", "refresh": "..." }`
- Refresh access: `POST /api/auth/jwt/refresh/` → `{ "access": "..." }`
- Verify token: `POST /api/auth/jwt/verify/`

Usage:

```http
POST /api/auth/jwt/token/
Content-Type: application/json

{"email":"admin@example.com","password":"<your password>"}
```

```http
GET /api/v1/me
Authorization: Bearer <access>
```

## Email configuration (Anymail / SMTP)

- Provider is selected via `EMAIL_PROVIDER` env var: `console` (default), `smtp`, `mailgun`, `postmark`, `sendgrid`, `resend` (via SMTP fallback).
- See `.env.example` for provider-specific variables.
- For local dev, `EMAIL_PROVIDER=console` prints emails to the console.

## Environment variables

- `DEBUG` (default: `true`)
- `SECRET_KEY` (set a strong value in non-dev)
- `ALLOWED_HOSTS` (comma-separated, no brackets, e.g. `127.0.0.1,localhost,0.0.0.0`)
- `API_DOCS_ENABLED` (default: `true` for dev)
- `DATABASE_URL` (e.g. `postgres://user:pass@localhost:5432/dbname`)
- `EMAIL_PROVIDER`, plus provider keys (see `.env.example`)

## Development utilities

Sort imports with isort (backend only):

```zsh
cd packages/backend
poetry run isort .
# Check mode (CI-friendly)
poetry run isort . --check --diff
```

## Troubleshooting

- DisallowedHost with 0.0.0.0: Set `ALLOWED_HOSTS=127.0.0.1,localhost,0.0.0.0` in `.env` (no brackets) and restart the server.

