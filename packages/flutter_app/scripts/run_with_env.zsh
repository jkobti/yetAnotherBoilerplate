#!/usr/bin/env zsh
# Convert a local .env file into --dart-define flags and run Flutter.
# Usage:
#   ./scripts/run_with_env.zsh customer   # runs lib/main.dart
#   ./scripts/run_with_env.zsh admin      # runs lib/main_admin.dart

set -euo pipefail

APP_DIR=$(cd -- "$(dirname "$0")/.." && pwd)
cd "$APP_DIR"

if [[ ! -f .env ]]; then
  echo "[run_with_env] No .env found in $APP_DIR; create one or use --dart-define-from-file=env/local.json"
  exit 1
fi

ENTRY="lib/main.dart"
if [[ ${1:-customer} == "admin" ]]; then
  ENTRY="lib/main_admin.dart"
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
exec flutter run -d chrome -t "$ENTRY" ${FLAGS[@]}
