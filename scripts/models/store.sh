#!/usr/bin/env bash
# scripts/models/store.sh — Create model store directory structure
# Part of the OldIntelClaw model management suite (Story 4.1)
#
# Creates the model store at ${OLDINTELCLAW_HOME}/models/ with backend-specific
# subdirectories and an initial manifest.json registry file. Idempotent: skips
# creation if directories already exist. Never overwrites an existing manifest.
#
# Overridable environment variables (for testing):
#   OLDINTELCLAW_HOME    — default: ~/.oldintelclaw
#   OLDINTELCLAW_DRY_RUN — set to 1 to print plan without creating anything
#
# Exit codes:
#   0 — store created (or already present), or dry-run plan printed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
MODELS_DIR="${OLDINTELCLAW_HOME}/models"
MANIFEST_FILE="${MODELS_DIR}/manifest.json"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

BACKEND_DIRS=(
    "${MODELS_DIR}/openvino"
    "${MODELS_DIR}/itrex"
    "${MODELS_DIR}/gguf"
)

MANIFEST_INITIAL='{
  "version": 1,
  "models": {}
}'

# ---------------------------------------------------------------------------
# Dry run — print plan and exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "model-store" "DRY RUN — showing plan only, no changes will be made"
    print_status "${STATUS_INFO}" "model-store" "PLAN — would create ${MODELS_DIR} with permissions 700"
    for dir in "${BACKEND_DIRS[@]}"; do
        print_status "${STATUS_INFO}" "model-store" "PLAN — would create ${dir}"
    done
    print_status "${STATUS_INFO}" "model-store" "PLAN — would create ${MANIFEST_FILE} if not present"
    exit 0
fi

# ---------------------------------------------------------------------------
# Create models/ root with permissions 700
# ---------------------------------------------------------------------------
if [[ ! -d "${MODELS_DIR}" ]]; then
    mkdir -p "${MODELS_DIR}"
    chmod 700 "${MODELS_DIR}"
    print_status "${STATUS_PASS}" "model-store" "Created ${MODELS_DIR}"
else
    chmod 700 "${MODELS_DIR}"
    print_status "${STATUS_INFO}" "model-store" "SKIP — ${MODELS_DIR} already exists"
fi

# ---------------------------------------------------------------------------
# Create backend subdirectories
# ---------------------------------------------------------------------------
for dir in "${BACKEND_DIRS[@]}"; do
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
        print_status "${STATUS_PASS}" "model-store" "Created ${dir}"
    else
        print_status "${STATUS_INFO}" "model-store" "SKIP — ${dir} already exists"
    fi
done

# ---------------------------------------------------------------------------
# Create manifest.json — skip if already present to preserve existing registry
# ---------------------------------------------------------------------------
if [[ ! -f "${MANIFEST_FILE}" ]]; then
    printf '%s\n' "${MANIFEST_INITIAL}" > "${MANIFEST_FILE}"
    print_status "${STATUS_PASS}" "model-store" "Created ${MANIFEST_FILE}"
else
    print_status "${STATUS_INFO}" "model-store" "SKIP — ${MANIFEST_FILE} already exists, preserving existing registry"
fi

exit 0
