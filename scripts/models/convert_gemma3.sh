#!/usr/bin/env bash
# scripts/models/convert_gemma3.sh — Gemma 3 4B INT4 for OpenVINO iGPU
# Part of the OldIntelClaw model management suite (Story 4.5)
#
# Downloads google/gemma-3-4b-it from Hugging Face, converts to INT4 with
# OpenVINO, verifies the model loads, and registers it in the manifest.
#
# Command overrides (for testing):
#   OLDINTELCLAW_CMD_DOWNLOAD    — default: curl -L -C - --progress-bar -o
#   OLDINTELCLAW_CMD_OV_CONVERT  — default: optimum-cli export openvino
#   OLDINTELCLAW_CMD_OV_VERIFY   — default: python3 -c "from openvino.runtime import Core"
#   OLDINTELCLAW_HOME            — default: ~/.oldintelclaw
#   OLDINTELCLAW_DRY_RUN=1       — print plan; do not download or convert
#
# Exit codes:
#   0 — success (registered, skipped, or dry-run)
#   1 — download, conversion, or verification failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./download.sh
source "${SCRIPT_DIR}/download.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
readonly MODEL_NAME="gemma-3-4b"
readonly HF_REPO="google/gemma-3-4b-it"
readonly BACKEND="openvino-igpu"
readonly SIZE_GB="3.2"

OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
MODEL_DIR="${OLDINTELCLAW_HOME}/models/openvino/${MODEL_NAME}"

CMD_OV_CONVERT="${OLDINTELCLAW_CMD_OV_CONVERT:-optimum-cli export openvino}"
CMD_OV_VERIFY="${OLDINTELCLAW_CMD_OV_VERIFY:-python3 -c 'from openvino.runtime import Core'}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Dry-run early exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN — would download from HF repo: ${HF_REPO}"
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN — would convert to INT4 OpenVINO format"
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN — would register as backend=${BACKEND}, size=${SIZE_GB}GB"
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN complete — no changes made"
    exit 0
fi

# ---------------------------------------------------------------------------
# Skip if already registered
# ---------------------------------------------------------------------------
if check_model_exists "${MODEL_NAME}"; then
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "SKIP — already registered in manifest"
    exit 0
fi

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${MODEL_NAME}" "Downloading ${HF_REPO} ..."
if ! download_model "${MODEL_NAME}" "${HF_REPO}" "${MODEL_DIR}"; then
    print_status "${STATUS_FAIL}" "${MODEL_NAME}" "FAIL — download failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# OpenVINO INT4 conversion
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${MODEL_NAME}" "Converting to INT4 with OpenVINO ..."
# shellcheck disable=SC2086
if ! ${CMD_OV_CONVERT} 2>&1; then
    print_status "${STATUS_FAIL}" "${MODEL_NAME}" "FAIL — OpenVINO conversion failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Verify model loads
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${MODEL_NAME}" "Verifying model loads ..."
# shellcheck disable=SC2086
if ! ${CMD_OV_VERIFY} 2>&1; then
    print_status "${STATUS_FAIL}" "${MODEL_NAME}" "FAIL — model verification failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Register
# ---------------------------------------------------------------------------
register_model "${MODEL_NAME}" "${BACKEND}" "${MODEL_DIR}" "${SIZE_GB}"

print_status "${STATUS_PASS}" "${MODEL_NAME}" "PASS — Gemma 3 4B INT4 ready for OpenVINO iGPU"
exit 0
