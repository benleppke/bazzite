#!/usr/bin/env bash
# Run rootful podman against the BUILD_ROOT storage instead of
# /var/lib/containers/storage. Used by the Justfile for local builds.
set -euo pipefail

: "${BUILD_ROOT:?BUILD_ROOT is not set; run this through just or set it in .env}"

STORAGE_CONF="${CONTAINERS_STORAGE_CONF:-${BUILD_ROOT}/containers/storage.conf}"
TMP_DIR="${BUILD_TMP_DIR:-${BUILD_ROOT}/tmp}"

if [[ ! -f "${STORAGE_CONF}" ]]; then
  echo "Error: ${STORAGE_CONF} not found. Run 'just setup-build-dir' first." >&2
  exit 1
fi

if [[ ! -d "${TMP_DIR}" ]]; then
  echo "Error: ${TMP_DIR} not found. Run 'just setup-build-dir' first." >&2
  exit 1
fi

exec sudo env \
  CONTAINERS_STORAGE_CONF="${STORAGE_CONF}" \
  TMPDIR="${TMP_DIR}" \
  podman "$@"
