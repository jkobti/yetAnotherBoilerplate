#!/usr/bin/env sh
set -eu

DEFAULT_WORKERS="${GUNICORN_WORKERS:-2}"
DEFAULT_BIND="${GUNICORN_BIND:-0.0.0.0:8000}"
DEFAULT_MODULE="${GUNICORN_MODULE:-boilerplate.asgi:application}"

# If the first arg is 'gunicorn', drop it (we add our own invocation)
if [ "${1:-}" = "gunicorn" ]; then
  shift
fi

# Allow passing additional gunicorn args, e.g. --log-level debug
# Example: docker run image --log-level debug
exec gunicorn "${DEFAULT_MODULE}" -k uvicorn.workers.UvicornWorker \
  --workers "${DEFAULT_WORKERS}" --bind "${DEFAULT_BIND}" "$@"
