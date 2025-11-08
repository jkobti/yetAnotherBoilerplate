#!/usr/bin/env zsh
# Convert a local .env file into --dart-define flags and run Flutter.
# Usage:
#   ./scripts/run_with_env.zsh customer           # runs lib/main.dart on Chrome
#   ./scripts/run_with_env.zsh customer android   # runs on an Android device/emulator
#   ./scripts/run_with_env.zsh admin chrome       # runs admin portal on Chrome

set -euo pipefail

APP_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
cd "$APP_DIR"

if [[ ! -f .env ]]; then
  echo "[run_with_env] No .env found in $APP_DIR; create one or use --dart-define-from-file=env/local.json"
  exit 1
fi

APP_KIND=${1:-customer}
if [[ $# -gt 0 ]]; then
  shift
fi

case "$APP_KIND" in
  customer|user)
    ENTRY="lib/main.dart"
    ;;
  admin)
    ENTRY="lib/main_admin.dart"
    ;;
  *)
    echo "[run_with_env] Unknown app kind: $APP_KIND"
    exit 1
    ;;
esac

DEVICE="chrome"
if [[ $# -gt 0 ]]; then
  DEVICE="$1"
  shift
fi

EXTRA_ARGS=()
if [[ $# -gt 0 ]]; then
  EXTRA_ARGS=("$@")
fi

# Read .env into dart-define flags (ignore comments and empty lines)
FLAGS=()
while IFS='=' read -r KEY VALUE; do
  [[ -z "$KEY" ]] && continue
  [[ "$KEY" == \#* ]] && continue
  # Trim and preserve raw value
  KEY_TRIMMED="${KEY//[[:space:]]/}"
  VALUE_TRIMMED="${${VALUE%%$'\r'}## }"
  FLAGS+=("--dart-define" "${KEY_TRIMMED}=${VALUE_TRIMMED}")
Done < <(grep -v '^\s*$' .env | grep -v '^#')

# Ensure API_BASE_URL has a default if not present
if ! grep -q '^API_BASE_URL=' .env; then
  FLAGS+=("--dart-define" "API_BASE_URL=http://localhost:8000")
fi

# Run Flutter
exec flutter run -d "$DEVICE" -t "$ENTRY" "${FLAGS[@]}" "${EXTRA_ARGS[@]}"
