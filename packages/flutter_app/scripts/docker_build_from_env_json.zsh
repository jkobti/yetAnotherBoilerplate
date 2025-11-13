#!/usr/bin/env zsh
# Build Flutter web images (customer/admin) using key/value pairs from a JSON env file.
# Converts each JSON entry into a --build-arg for docker build so values are not copied into the image context.
# Usage examples:
#   ./scripts/docker_build_from_env_json.zsh web env/prod.json yab-web:prod Dockerfile.web
#   ./scripts/docker_build_from_env_json.zsh admin env/prod.json yab-admin:prod Dockerfile.admin.web
# Arguments:
#   1: app kind (web|admin)
#   2: JSON file path relative to package root (e.g., env/prod.json)
#   3: image tag (e.g., yab-web:prod)
#   4: Dockerfile name (Dockerfile.web | Dockerfile.admin.web)
#
# Notes:
# - Firebase & API config values are public identifiers; do NOT place real secrets here.
# - For truly sensitive values (Sentry DSN, auth tokens) prefer runtime config injection via a separate served file or env vars in a dynamic backend.

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
# Determine repo root for monorepo path dependencies (ui_kit)
ROOT_DIR="$(git -C "${APP_DIR}" rev-parse --show-toplevel 2>/dev/null || echo "${APP_DIR}/../..")"
cd "${ROOT_DIR}"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <web|admin> <json-file> <image-tag> <Dockerfile>" >&2
  exit 1
fi

APP_KIND="$1"; shift
JSON_FILE="$1"; shift
IMAGE_TAG="$1"; shift
DOCKERFILE_NAME="$1"; shift || true

if [[ ! -f "$JSON_FILE" ]]; then
  echo "[docker_build_from_env_json] JSON file not found: $JSON_FILE" >&2
  exit 1
fi

case "$APP_KIND" in
  web|customer|user)
    DOCKERFILE_PATH="$DOCKERFILE_NAME"
    ;;
  admin)
    DOCKERFILE_PATH="$DOCKERFILE_NAME"
    ;;
  *)
    echo "[docker_build_from_env_json] Unknown app kind: $APP_KIND" >&2
    exit 1
    ;;
 esac

FULL_DOCKERFILE_PATH="packages/flutter_app/$DOCKERFILE_PATH"
if [[ ! -f "$FULL_DOCKERFILE_PATH" ]]; then
  echo "[docker_build_from_env_json] Dockerfile not found: $FULL_DOCKERFILE_PATH" >&2
  exit 1
fi

# Build args from JSON (flat key/value)
BUILD_ARGS=()
# Use jq to convert entries; skip nulls
while IFS=$'\n' read -r line; do
  BUILD_ARGS+=("--build-arg" "$line")
done < <(jq -r 'to_entries | map(select(.value != null)) | .[] | "\(.key)=\(.value | gsub(" \\(?optional\\)?"; ""))"' "$JSON_FILE")

# Ensure API_BASE_URL fallback if missing
if ! jq -e '.API_BASE_URL' "$JSON_FILE" >/dev/null 2>&1; then
  BUILD_ARGS+=("--build-arg" "API_BASE_URL=http://localhost:8000")
fi

set -x
DOCKER_BUILDKIT=1 docker build -f "$FULL_DOCKERFILE_PATH" -t "$IMAGE_TAG" ${BUILD_ARGS[@]} "$ROOT_DIR"
set +x

echo "[docker_build_from_env_json] Built $IMAGE_TAG using $JSON_FILE with ${#BUILD_ARGS[@]} build args (context: $ROOT_DIR)."
