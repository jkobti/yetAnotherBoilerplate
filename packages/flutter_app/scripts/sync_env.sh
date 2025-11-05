#!/bin/bash
set -euo pipefail

# Copy env/local.json into web/env/local.json so the service worker can fetch it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/.."
SRC="${APP_DIR}/env/local.json"
DST_DIR="${APP_DIR}/web/env"
DST="${DST_DIR}/local.json"

if [[ ! -f "${SRC}" ]]; then
  echo "Source env not found: ${SRC}" >&2
  exit 1
fi

mkdir -p "${DST_DIR}"
cp "${SRC}" "${DST}"
echo "Copied ${SRC} -> ${DST}"
