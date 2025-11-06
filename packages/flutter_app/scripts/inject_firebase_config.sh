#!/bin/bash
set -euo pipefail

# Inject Firebase config into the service worker at build time.
# This embeds the config directly in the service worker instead of fetching it at runtime.
#
# Usage:
#   ./scripts/inject_firebase_config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
ENV_FILE="${APP_DIR}/env/local.json"
TEMPLATE_FILE="${APP_DIR}/web/firebase-messaging-sw.template.js"
OUTPUT_FILE="${APP_DIR}/web/firebase-messaging-sw.js"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Warning: ${ENV_FILE} not found. Service worker will be created without Firebase config." >&2
  # Create a minimal service worker without Firebase
  cat > "${OUTPUT_FILE}" <<'EOF'
/*
  Firebase Cloud Messaging service worker (web push).
  Firebase config not provided - push notifications disabled.
*/
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  self.clients.claim();
});
EOF
  exit 0
fi

# Read Firebase config from env file
FIREBASE_API_KEY=$(jq -r '.FIREBASE_API_KEY // ""' "${ENV_FILE}")
FIREBASE_APP_ID=$(jq -r '.FIREBASE_APP_ID // ""' "${ENV_FILE}")
FIREBASE_MESSAGING_SENDER_ID=$(jq -r '.FIREBASE_MESSAGING_SENDER_ID // ""' "${ENV_FILE}")
FIREBASE_PROJECT_ID=$(jq -r '.FIREBASE_PROJECT_ID // ""' "${ENV_FILE}")
FIREBASE_AUTH_DOMAIN=$(jq -r '.FIREBASE_AUTH_DOMAIN // ""' "${ENV_FILE}")
FIREBASE_STORAGE_BUCKET=$(jq -r '.FIREBASE_STORAGE_BUCKET // ""' "${ENV_FILE}")

# Check if push notifications are enabled
PUSH_ENABLED=$(jq -r '.PUSH_NOTIFICATIONS_ENABLED // "false"' "${ENV_FILE}")

if [[ "${PUSH_ENABLED}" != "true" ]] || [[ -z "${FIREBASE_API_KEY}" ]] || [[ -z "${FIREBASE_APP_ID}" ]] || \
   [[ -z "${FIREBASE_MESSAGING_SENDER_ID}" ]] || [[ -z "${FIREBASE_PROJECT_ID}" ]]; then
  echo "Warning: Push notifications disabled or incomplete Firebase config. Creating minimal service worker." >&2
  # Create a minimal service worker without Firebase
  cat > "${OUTPUT_FILE}" <<'EOF'
/*
  Firebase Cloud Messaging service worker (web push).
  Firebase config not provided - push notifications disabled.
*/
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  self.clients.claim();
});
EOF
  exit 0
fi

# Build Firebase config object
FIREBASE_CONFIG="{"
FIREBASE_CONFIG+="\"apiKey\":\"${FIREBASE_API_KEY}\","
FIREBASE_CONFIG+="\"appId\":\"${FIREBASE_APP_ID}\","
FIREBASE_CONFIG+="\"messagingSenderId\":\"${FIREBASE_MESSAGING_SENDER_ID}\","
FIREBASE_CONFIG+="\"projectId\":\"${FIREBASE_PROJECT_ID}\""

if [[ -n "${FIREBASE_AUTH_DOMAIN}" ]] && [[ "${FIREBASE_AUTH_DOMAIN}" != "null" ]]; then
  FIREBASE_CONFIG+=",\"authDomain\":\"${FIREBASE_AUTH_DOMAIN}\""
fi

if [[ -n "${FIREBASE_STORAGE_BUCKET}" ]] && [[ "${FIREBASE_STORAGE_BUCKET}" != "null" ]]; then
  FIREBASE_CONFIG+=",\"storageBucket\":\"${FIREBASE_STORAGE_BUCKET}\""
fi

FIREBASE_CONFIG+="}"

# Replace placeholder in template
if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  echo "Error: Template file not found: ${TEMPLATE_FILE}" >&2
  exit 1
fi

sed "s|__FIREBASE_CONFIG_PLACEHOLDER__|${FIREBASE_CONFIG}|g" "${TEMPLATE_FILE}" > "${OUTPUT_FILE}"

echo "Injected Firebase config into ${OUTPUT_FILE}"
