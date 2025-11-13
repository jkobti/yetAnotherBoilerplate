# Backend API Dockerfile (multi-stage)
# Provides a production-ready container for the Django ASGI app.
# Notes:
# - Uses Poetry for dependency resolution; add a poetry.lock for reproducible builds.
# - Installs optional uvicorn dependency for ASGI gunicorn worker.
# - Defers worker image (background tasks) until queue system chosen.

ARG PYTHON_VERSION=3.11-slim

FROM python:${PYTHON_VERSION} AS builder
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false \
    PIP_NO_CACHE_DIR=on
WORKDIR /app

# System deps (libpq for psycopg2, build-essential for any native wheels)
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install --upgrade pip \
    && pip install poetry==1.8.3

# Copy only dependency manifest first for layer caching
COPY pyproject.toml ./
# If/when poetry.lock exists, copy it too for locked builds
# COPY poetry.lock ./

# Install production dependencies (main group only)
RUN poetry install --only main --no-root || echo "Warning: poetry.lock missing; dependencies not pinned."
# Ensure optional uvicorn dependency present for ASGI worker
RUN pip install uvicorn

# Copy project source
COPY . .

# Optionally collect static or run build steps here (deferred until runtime/init containers)

FROM python:${PYTHON_VERSION} AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=boilerplate.settings \
    APP_HOME=/app
WORKDIR /app

# Copy installed site-packages & binaries from builder layer
COPY --from=builder /usr/local /usr/local

# Copy application source (keep separate for potential volume mounts)
COPY . .

# Copy entrypoint script (needs root) before dropping privileges
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create non-root user
RUN useradd -m appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Gunicorn with uvicorn worker for ASGI Django
# Tune workers later (env-controlled). Default: 2 workers.
ENV GUNICORN_WORKERS=2 \
    GUNICORN_BIND=0.0.0.0:8000 \
    GUNICORN_MODULE=boilerplate.asgi:application

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["gunicorn"]

# Health probes handled by Kubernetes (e.g., GET /health/). No Docker HEALTHCHECK to keep image minimal.

# Minimal runtime image now ready.
