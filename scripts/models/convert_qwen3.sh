#!/usr/bin/env bash
# scripts/models/convert_qwen3.sh — Qwen3-8B-Thinking INT4 for ITREX CPU
# Part of the OldIntelClaw model management suite (Story 4.6)
#
# Downloads Qwen/Qwen3-8B-Thinking from Hugging Face, quantizes to INT4 with
# Intel Extension for Transformers (ITREX), verifies the model loads, and
# registers it in the manifest.
#
# Command overrides (for testing):
#   OLDINTELCLAW_CMD_DOWNLOAD        — default: curl -L -C - --progress-bar -o
#   OLDINTELCLAW_CMD_ITREX_QUANTIZE  — default: python3 -m intel_extension_for_transformers.neural_chat.tools.quantization
#   OLDINTELCLAW_CMD_ITREX_VERIFY    — default: python3 -c "from intel_extension_for_transformers.transformers import AutoModelForCausalLM"
#   OLDINTELCLAW_HOME                — default: ~/.oldintelclaw
#   OLDINTELCLAW_DRY_RUN=1           — print plan; do not download or quantize
#
# Exit codes:
#   0 — success (registered, skipped, or dry-run)
#   1 — download, quantization, or verification failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./download.sh
source "${SCRIPT_DIR}/download.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
readonly MODEL_NAME="qwen3-8b"
readonly HF_REPO="Qwen/Qwen3-8B-Thinking"
readonly BACKEND="itrex-cpu"
readonly SIZE_GB="5.5"

OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
MODEL_DIR="${OLDINTELCLAW_HOME}/models/itrex/${MODEL_NAME}"

CMD_ITREX_QUANTIZE="${OLDINTELCLAW_CMD_ITREX_QUANTIZE:-python3 -m intel_extension_for_transformers.neural_chat.tools.quantization}"
CMD_ITREX_VERIFY="${OLDINTELCLAW_CMD_ITREX_VERIFY:-python3 -c 'from intel_extension_for_transformers.transformers import AutoModelForCausalLM'}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Dry-run early exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN — would download from HF repo: ${HF_REPO}"
    print_status "${STATUS_INFO}" "${MODEL_NAME}" "DRY RUN — would quantize to INT4 with ITREX"
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
# ITREX INT4 quantization
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${MODEL_NAME}" "Quantizing to INT4 with ITREX ..."
# shellcheck disable=SC2086
if ! ${CMD_ITREX_QUANTIZE} 2>&1; then
    print_status "${STATUS_FAIL}" "${MODEL_NAME}" "FAIL — ITREX quantization failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Verify model loads
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${MODEL_NAME}" "Verifying model loads ..."
# shellcheck disable=SC2086
if ! ${CMD_ITREX_VERIFY} 2>&1; then
    print_status "${STATUS_FAIL}" "${MODEL_NAME}" "FAIL — model verification failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Register
# ---------------------------------------------------------------------------
register_model "${MODEL_NAME}" "${BACKEND}" "${MODEL_DIR}" "${SIZE_GB}"

print_status "${STATUS_PASS}" "${MODEL_NAME}" "PASS — Qwen3-8B-Thinking INT4 ready for ITREX CPU"
exit 0
