#!/usr/bin/env bash
# scripts/models/download_smollm3.sh — SmolLM3-3B GGUF for ZeroClaw Native
# Part of the OldIntelClaw model management suite (Story 4.7)
#
# Downloads the SmolLM3-3B GGUF file from Hugging Face, verifies the file is
# non-empty, and registers it in the manifest. No conversion step required.
#
# Command overrides (for testing):
#   OLDINTELCLAW_CMD_DOWNLOAD — default: curl -L -C - --progress-bar -o
#   OLDINTELCLAW_HOME         — default: ~/.oldintelclaw
#   OLDINTELCLAW_DRY_RUN=1    — print plan; do not download
#
# Exit codes:
#   0 — success (registered, skipped, or dry-run)
#   1 — download or verification failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./download.sh
source "${SCRIPT_DIR}/download.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
readonly MODEL_NAME="smollm3-3b"
readonly HF_REPO="HuggingFaceTB/SmolLM3-3B-GGUF"
readonly BACKEND="gguf-native"
readonly SIZE_GB="2.2"
readonly GGUF_FILENAME="smollm3-3b.gguf"

OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
GGUF_DIR="${OLDINTELCLAW_HOME}/models/gguf"
GGUF_FILE="${GGUF_DIR}/${GGUF_FILENAME}"

CMD_DOWNLOAD="${OLDINTELCLAW_CMD_DOWNLOAD:-curl -L -C - --progress-bar -o}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Dry-run early exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN — would download ${GGUF_FILENAME} from ${HF_REPO}"
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN — would verify GGUF file is non-empty"
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
# Ensure output directory exists
# ---------------------------------------------------------------------------
mkdir -p "${GGUF_DIR}"

# ---------------------------------------------------------------------------
# Download GGUF file
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${MODEL_NAME}" "Downloading ${GGUF_FILENAME} ..."
# shellcheck disable=SC2086
if ! ${CMD_DOWNLOAD} "${GGUF_FILE}" "https://huggingface.co/${HF_REPO}/resolve/main/${GGUF_FILENAME}" 2>&1; then
    print_status "${STATUS_FAIL}" "${MODEL_NAME}" "FAIL — download failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Verify file exists and is non-empty
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${MODEL_NAME}" "Verifying GGUF file is non-empty ..."
if [[ ! -f "${GGUF_FILE}" ]] || [[ ! -s "${GGUF_FILE}" ]]; then
    print_status "${STATUS_FAIL}" "${MODEL_NAME}" "FAIL — GGUF file missing or empty after download"
    exit 1
fi

# ---------------------------------------------------------------------------
# Register
# ---------------------------------------------------------------------------
register_model "${MODEL_NAME}" "${BACKEND}" "${GGUF_FILE}" "${SIZE_GB}"

print_status "${STATUS_PASS}" "${MODEL_NAME}" "PASS — SmolLM3-3B GGUF ready for ZeroClaw Native"
exit 0
