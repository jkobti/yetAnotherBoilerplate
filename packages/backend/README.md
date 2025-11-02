# Backend service (Django)

This package contains the Django backend for yetAnotherBoilerplate.


How limits are counted

- Authenticated requests: `UserRateThrottle` applies per authenticated user (each `request.user` has its own counter).
- Anonymous requests: `AnonRateThrottle` applies per client IP address.
- Scoped throttles: `ScopedRateThrottle` still counts per user (or per IP if anonymous), but maintains separate counters per `throttle_scope`.

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

### CORS for web development

When running the Flutter web app from `flutter run -d chrome`, it serves from a random localhost port, which is a different origin than the Django dev server. To allow cross-origin calls during development we enable CORS by default in `DEBUG` mode using `django-cors-headers`.

If you haven't installed dependencies after pulling changes, install them:

```zsh
cd packages/backend
poetry install
```

You can also explicitly control CORS via environment variables:

- `CORS_ALLOW_ALL_ORIGINS` (default: `DEBUG`)
- `CORS_ALLOWED_ORIGIN_REGEXES` (default: allow `http://localhost:*` and `http://127.0.0.1:*`)

For production, set explicit allowed origins instead of allowing all.

## JWT authentication

Endpoints:

- Obtain tokens: `POST /api/auth/jwt/token/` → `{ "access": "...", "refresh": "..." }`
- Refresh access: `POST /api/auth/jwt/refresh/` → `{ "access": "..." }`
- Verify token: `POST /api/auth/jwt/verify/`

## Registration

- Create account: `POST /api/auth/register/`

Request body:

```json
{
	"email": "user@example.com",
	"password": "<min 8 chars>",
	"first_name": "Optional",
	"last_name": "Optional"
}
```

Response (201):

```json
{
	"access": "<access>",
	"refresh": "<refresh>",
	"user": { "id": "...", "email": "user@example.com", "is_staff": false, ... }
}
```

Notes:
- The endpoint is throttled via `AnonRateThrottle` and validates unique email.
- For production, consider email verification before issuing tokens.

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

## Running tests

```zsh
cd packages/backend
poetry run pytest -q
```

## Troubleshooting

- DisallowedHost with 0.0.0.0: Set `ALLOWED_HOSTS=127.0.0.1,localhost,0.0.0.0` in `.env` (no brackets) and restart the server.

## Require authentication on an endpoint

Use DRF permissions on your views. For class-based views:

```python
# apps/public_api/views.py
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView


class MyProtectedView(APIView):
	permission_classes = [IsAuthenticated]

	def get(self, request):
		return Response({"message": f"Hello, {request.user.email}"})
```

For function-based views:

```python
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_protected_view(request):
	return Response({"message": f"Hello, {request.user.email}"})
```

When using JWT, include the header: `Authorization: Bearer <access-token>`.

## Rate limit an endpoint

Global throttles are set in `settings.py` via `REST_FRAMEWORK.DEFAULT_THROTTLE_CLASSES` and `DEFAULT_THROTTLE_RATES`.
To apply a specific rate to a view, use `ScopedRateThrottle` and a `throttle_scope` value, then define a rate for that scope in settings.

Class-based view example:

```python
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework.response import Response


class CreateSomethingView(APIView):
	throttle_classes = [ScopedRateThrottle]
	throttle_scope = "create_something"

	def post(self, request):
		# ... create logic ...
		return Response({"ok": True})
```

Function-based view example:

```python
from rest_framework.decorators import api_view, throttle_classes
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle


@api_view(["POST"])
@throttle_classes([ScopedRateThrottle])
def create_something(request):
	create_something.throttle_scope = "create_something"
	return Response({"ok": True})
```

Add a matching rate in `settings.py` (already seeded with examples):

```python
REST_FRAMEWORK = {
	# ...
	"DEFAULT_THROTTLE_RATES": {
		"anon": "100/day",
		"user": "1000/day",
		"admin": "2/minute",
		"create_something": "10/minute",  # custom scope
	},
}
```


Admin endpoints

- By default, admin views are not throttled to avoid slowing internal workflows. Rely on RBAC and auditing.
- If you want to throttle an admin view, add `ScopedRateThrottle` plus a scope (e.g., `admin`) on that view, and define its rate under `REST_FRAMEWORK.DEFAULT_THROTTLE_RATES`.
- When throttled, responses use HTTP 429 and include a `Retry-After` header; our problem-details error wrapper preserves these headers.

Per-view override checklist

- Add `throttle_classes = [ScopedRateThrottle]` on the view.
- Set `throttle_scope = "your_scope"` on the view.
- Define the rate under `REST_FRAMEWORK.DEFAULT_THROTTLE_RATES.your_scope`.
