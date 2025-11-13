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

## Container (Docker) Usage

Build the image (from repo root or this directory):

```zsh
docker build -f packages/backend/Dockerfile packages/backend -t yetanotherboilerplate/backend:dev
```

Run the API container (SQLite fallback if `DATABASE_URL` not set):

```zsh
docker run --rm -p 8000:8000 \
	-e DJANGO_SETTINGS_MODULE=boilerplate.settings \
	yetanotherboilerplate/backend:dev
```

Quick persistent dev run (bind-mount project directory so SQLite data survives container restarts):

```zsh
docker run --rm -p 8000:8000 \
	-v "$PWD/packages/backend":/app \
	-e DJANGO_SETTINGS_MODULE=boilerplate.settings \
	yetanotherboilerplate/backend:dev
```

Because the whole directory is mounted, the `.env` file inside `packages/backend` is available to Django automatically (loaded by `django-environ`). You do NOT need `--env-file` here unless you want to override values without mounting source. If you prefer injecting env vars explicitly while still mounting code:

```zsh
docker run --rm -p 8000:8000 \
	-v "$PWD/packages/backend":/app \
	--env-file packages/backend/.env \
	yetanotherboilerplate/backend:dev
```

Minimal variant mounting only the database file (create it first if missing):

```zsh
touch packages/backend/db.sqlite3
docker run --rm -p 8000:8000 \
	-v "$PWD/packages/backend/db.sqlite3":/app/db.sqlite3 \
	yetanotherboilerplate/backend:dev
```

Add `.env` when mounting only the database file (since the full folder with `.env` is not mounted):

```zsh
touch packages/backend/db.sqlite3
docker run --rm -p 8000:8000 \
	-v "$PWD/packages/backend/db.sqlite3":/app/db.sqlite3 \
	--env-file packages/backend/.env \
	yetanotherboilerplate/backend:dev
```

With Postgres (example):

```zsh
export DATABASE_URL="postgres://user:pass@localhost:5432/appdb"
docker run --rm -p 8000:8000 \
	-e DJANGO_SETTINGS_MODULE=boilerplate.settings \
	-e DATABASE_URL="$DATABASE_URL" \
	yetanotherboilerplate/backend:dev
```

Run migrations using the same image (one-off):

```zsh
docker run --rm \
	-e DJANGO_SETTINGS_MODULE=boilerplate.settings \
	-e DATABASE_URL="$DATABASE_URL" \
	yetanotherboilerplate/backend:dev \
	python manage.py migrate
```

Create a superuser:

```zsh
docker run --rm -it \
	-e DJANGO_SETTINGS_MODULE=boilerplate.settings \
	-e DATABASE_URL="$DATABASE_URL" \
	yetanotherboilerplate/backend:dev \
	python manage.py createsuperuser --email admin@example.com
```

Customize gunicorn worker count & bind address:

```zsh
docker run --rm -p 8000:8000 \
	-e GUNICORN_WORKERS=4 -e GUNICORN_BIND=0.0.0.0:8000 \
	yetanotherboilerplate/backend:dev
```

#### What are "workers" here?

In this context "workers" refers to Gunicorn worker *processes* handling HTTP requests for the Django ASGI app (each runs an event loop via the `uvicorn.workers.UvicornWorker` class). They are not background task consumers like Celery/RQ/Sidekiq. We have **no separate background job worker service yet** (that was explicitly deferred in the Kubernetes plan until a queue system is chosen). Adjusting `GUNICORN_WORKERS` only changes the number of concurrent Gunicorn processes for inbound web traffic.

Guidance:
- Start with 2–4 workers for local/dev.
- For CPU-bound endpoints: roughly `CPU cores * 2` can help.
- For mostly I/O-bound async work, fewer workers are often fine because each async loop can handle many concurrent requests.
- Avoid very high counts; context switching and memory overhead rise quickly.

When we introduce a background task system later it will be a **separate deployment/pod** (often just called a "worker"), distinct from these Gunicorn HTTP workers.

Mount source for quick local iteration (not production):

```zsh
docker run --rm -p 8000:8000 \
	-v "$PWD/packages/backend":/app \
	-e DJANGO_SETTINGS_MODULE=boilerplate.settings \
	yetanotherboilerplate/backend:dev
```

Health check (adjust path if needed):

```zsh
curl -i http://localhost:8000/health/
```

Recommended next steps:
- Add a `poetry.lock` to speed/lock image builds.
- Introduce a dedicated migrations job in Helm using this same image.

### SQLite persistence (dev only)

By default, running the container without a volume means the SQLite database file created inside the container is ephemeral (lost when the container is removed). To persist data between runs while still using SQLite for quick experiments, bind mount the project directory so `db.sqlite3` lives on your host:

```zsh
# From repository root
docker run --rm -p 8000:8000 \
	-v "$PWD/packages/backend":/app \
	-e DJANGO_SETTINGS_MODULE=boilerplate.settings \
	yetanotherboilerplate/backend:dev
```

This keeps `packages/backend/db.sqlite3` on your machine across container restarts. Use only for local development—SQLite is not suitable for multi-replica or production Kubernetes deployments. Prefer Postgres (see example above) when you need realistic concurrency or durability.

### Environment variables in Docker

The project uses `django-environ` and automatically reads a `.env` file located at `packages/backend/.env` (loaded in `settings.py` via `Env.read_env`). You have two ways to provide configuration when running the container:

1. Bind mount the source (contains `.env`), letting django-environ read the file:
	 ```zsh
	 docker run --rm -p 8000:8000 \
		 -v "$PWD/packages/backend":/app \
		 yetanotherboilerplate/backend:dev
	 ```
	 (If `DJANGO_SETTINGS_MODULE` differs from default you can still pass `-e DJANGO_SETTINGS_MODULE=boilerplate.settings`.)

2. Use `--env-file` so Docker injects variables directly (no need for the file inside the container):
	 ```zsh
	 docker run --rm -p 8000:8000 \
		 --env-file packages/backend/.env \
		 yetanotherboilerplate/backend:dev
	 ```
	 This bypasses reading the file from disk; all values become environment variables available to `django-environ`.

3. Pass individual `-e` flags (handy for quick overrides):
	 ```zsh
	 docker run --rm -p 8000:8000 \
		 -e DEBUG=false -e SECRET_KEY="replace-me" -e DATABASE_URL="$DATABASE_URL" \
		 yetanotherboilerplate/backend:dev
	 ```

Notes:
- Do NOT bake secrets into the image via `Dockerfile`; keep them runtime-injected.
- For production/Kubernetes prefer external secret managers (Vault, cloud secrets) or sealed secrets instead of plain `.env`.
- If you omit both a bind mount and `--env-file`, default values defined in `settings.py` apply (e.g. SQLite, insecure dev secret).

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
- Gunicorn shows `invalid int value: '${GUNICORN_WORKERS}'`: This means you are using an older locally cached image built before the entrypoint script fix (it passed the literal variable). Rebuild the image so the shell script handles defaults:
	```zsh
	docker build -f packages/backend/Dockerfile packages/backend -t yetanotherboilerplate/backend:dev
	```
	Verify the container has the correct entrypoint & cmd:
	```zsh
	docker inspect --format '{{.Config.Entrypoint}} {{.Config.Cmd}}' yetanotherboilerplate/backend:dev
	# Expected: [/usr/local/bin/docker-entrypoint.sh] [gunicorn]
	```
	Then run again (optionally clearing old dangling images):
	```zsh
	docker run --rm -p 8000:8000 yetanotherboilerplate/backend:dev
	```
	You can override workers with `-e GUNICORN_WORKERS=4`; if omitted the default (2) is applied.
- Port already allocated on 8000 after Ctrl-C: A process or previous container still holds the port. Find and free it:
	```zsh
	# See which process is listening
	lsof -iTCP:8000 -sTCP:LISTEN

	# Or with netstat (macOS via lsof is preferable)
	sudo lsof -nP -iTCP:8000 | grep LISTEN

	# List running containers publishing 8000
	docker ps --filter "publish=8000"

	# If a container still runs, stop or kill it
	docker stop <container_id_or_name> || docker kill <container_id_or_name>

	# If it's a local dev server (manage.py runserver), kill PID
	kill -TERM <pid>
	```
	After freeing the port, re-run:
	```zsh
	docker run --rm --name backend-dev -p 8000:8000 yetanotherboilerplate/backend:dev
	```
	For easier management, name the container and stop it cleanly:
	```zsh
	docker stop backend-dev   # then port should free immediately
	```
	If you need a different host port (leave container internal port 8000):
	```zsh
	docker run --rm -p 8080:8000 yetanotherboilerplate/backend:dev
	# App available at http://localhost:8080
	```

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
