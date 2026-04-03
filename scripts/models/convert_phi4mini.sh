#!/usr/bin/env bash
# scripts/models/convert_phi4mini.sh — Phi-4-mini INT4 → OpenVINO iGPU pipeline
# Part of the OldIntelClaw model management suite (Story 4.3)
#
# Downloads microsoft/Phi-4-mini-instruct from Hugging Face and converts it
# to OpenVINO IR INT4 format for use on Intel integrated GPU.
#
# Overridable environment variables:
#   OLDINTELCLAW_HOME           — default: ~/.oldintelclaw
#   OLDINTELCLAW_CMD_DOWNLOAD   — override download command
#   OLDINTELCLAW_CMD_CHECKSUM   — override checksum command
#   OLDINTELCLAW_CMD_OV_CONVERT — override OpenVINO conversion command
#                                 default: optimum-cli export openvino ...
#   OLDINTELCLAW_CMD_OV_VERIFY  — override OpenVINO model load verification
#                                 default: python3 -c "from openvino import Core; ..."
#   OLDINTELCLAW_DRY_RUN        — if "1", print plan only, no changes made
#
# Exit codes:
#   0 — success (model registered, already present, or dry-run)
#   1 — failure (download, conversion, or verification error)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./download.sh
source "${SCRIPT_DIR}/download.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
readonly _MODEL_NAME="phi-4-mini"
readonly _HF_REPO="microsoft/Phi-4-mini-instruct"
readonly _BACKEND="openvino-igpu"
readonly _SIZE_GB="3.0"

OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
readonly _OUTPUT_DIR="${OLDINTELCLAW_HOME}/models/openvino/${_MODEL_NAME}"

# Command overrides — defaults to real OpenVINO tooling
_CMD_OV_CONVERT="${OLDINTELCLAW_CMD_OV_CONVERT:-optimum-cli export openvino --model microsoft/Phi-4-mini-instruct --weight-format int4}"
_CMD_OV_VERIFY="${OLDINTELCLAW_CMD_OV_VERIFY:-python3 -c \"from openvino import Core; Core().read_model('${_OUTPUT_DIR}/openvino_model.xml')\"}"

DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Dry run — print plan and exit cleanly
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — Phi-4-mini INT4 → OpenVINO iGPU conversion plan"
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — would download from HF repo: ${_HF_REPO}"
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — would convert with: ${_CMD_OV_CONVERT}"
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — output dir: ${_OUTPUT_DIR}"
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — would register as backend=${_BACKEND}, size=${_SIZE_GB}GB"
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN complete — no changes made"
    exit 0
fi

# ---------------------------------------------------------------------------
# Check if model already registered → skip
# ---------------------------------------------------------------------------
if check_model_exists "${_MODEL_NAME}"; then
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "SKIP — already registered in manifest"
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 1: Download model from Hugging Face
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${_MODEL_NAME}" "Step 1/3 — downloading from HF repo: ${_HF_REPO}"

if ! download_model "${_MODEL_NAME}" "${_HF_REPO}" "${_OUTPUT_DIR}"; then
    print_status "${STATUS_FAIL}" "${_MODEL_NAME}" "FAIL — download step failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: Convert to OpenVINO IR INT4
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${_MODEL_NAME}" "Step 2/3 — converting to OpenVINO IR INT4 format"

# shellcheck disable=SC2086
if ! ${_CMD_OV_CONVERT} 2>&1; then
    print_status "${STATUS_FAIL}" "${_MODEL_NAME}" "FAIL — OpenVINO conversion failed"
    exit 1
fi

print_status "${STATUS_PASS}" "${_MODEL_NAME}" "Conversion to OpenVINO IR INT4 complete"

# ---------------------------------------------------------------------------
# Step 3: Verify model loads in OpenVINO
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${_MODEL_NAME}" "Step 3/3 — verifying model loads in OpenVINO"

# shellcheck disable=SC2086
if ! ${_CMD_OV_VERIFY} 2>&1; then
    print_status "${STATUS_FAIL}" "${_MODEL_NAME}" "FAIL — OpenVINO model verification failed"
    exit 1
fi

print_status "${STATUS_PASS}" "${_MODEL_NAME}" "OpenVINO model verification passed"

# ---------------------------------------------------------------------------
# Register in manifest
# ---------------------------------------------------------------------------
register_model "${_MODEL_NAME}" "${_BACKEND}" "${_OUTPUT_DIR}" "${_SIZE_GB}"

print_status "${STATUS_PASS}" "${_MODEL_NAME}" "PASS — INSTALLED (backend=${_BACKEND}, size=${_SIZE_GB}GB)"
exit 0
