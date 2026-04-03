#!/usr/bin/env bash
# scripts/models/convert_deepseek_r1.sh — DeepSeek-R1-Distill-Qwen-7B INT4 → ITREX CPU
# Part of the OldIntelClaw model management suite (Story 4.4)
#
# Downloads deepseek-ai/DeepSeek-R1-Distill-Qwen-7B from Hugging Face and
# quantizes it to INT4 using Intel Extension for Transformers (ITREX) for
# CPU inference.
#
# Overridable environment variables:
#   OLDINTELCLAW_HOME              — default: ~/.oldintelclaw
#   OLDINTELCLAW_CMD_DOWNLOAD      — override download command
#   OLDINTELCLAW_CMD_CHECKSUM      — override checksum command
#   OLDINTELCLAW_CMD_ITREX_QUANTIZE — override ITREX quantization command
#                                    default: python3 -c "from intel_extension_for_transformers..."
#   OLDINTELCLAW_CMD_ITREX_VERIFY  — override ITREX load verification
#   OLDINTELCLAW_DRY_RUN           — if "1", print plan only, no changes made
#
# Exit codes:
#   0 — success (model registered, already present, or dry-run)
#   1 — failure (download, quantization, or verification error)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./download.sh
source "${SCRIPT_DIR}/download.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
readonly _MODEL_NAME="deepseek-r1-7b"
readonly _HF_REPO="deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"
readonly _BACKEND="itrex-cpu"
readonly _SIZE_GB="5.2"

OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
readonly _OUTPUT_DIR="${OLDINTELCLAW_HOME}/models/itrex/${_MODEL_NAME}"

# Command overrides — defaults to real ITREX tooling
_CMD_ITREX_QUANTIZE="${OLDINTELCLAW_CMD_ITREX_QUANTIZE:-python3 -c \"from intel_extension_for_transformers.transformers import AutoModelForCausalLM; from intel_extension_for_transformers.transformers.llm.quantization.utils import convert_to_quantized_model; from transformers import AutoTokenizer; from neural_compressor.config import PostTrainingQuantConfig, TuningCriterion; model_name='deepseek-ai/DeepSeek-R1-Distill-Qwen-7B'; config=PostTrainingQuantConfig(approach='weight_only', backend='ipex', tuning_criterion=TuningCriterion(max_trials=600)); AutoModelForCausalLM.from_pretrained(model_name, quantization_config=config, save_compressed=True, use_neural_speed=False).save_pretrained('${_OUTPUT_DIR}')\"}"
_CMD_ITREX_VERIFY="${OLDINTELCLAW_CMD_ITREX_VERIFY:-python3 -c \"from intel_extension_for_transformers.transformers import AutoModelForCausalLM; AutoModelForCausalLM.from_pretrained('${_OUTPUT_DIR}')\"}"

DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Dry run — print plan and exit cleanly
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — DeepSeek-R1-7B INT4 → ITREX CPU quantization plan"
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — would download from HF repo: ${_HF_REPO}"
    print_status "${STATUS_INFO}" "${_MODEL_NAME}" "DRY RUN — would quantize with ITREX WeightOnlyQuant INT4"
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
# Step 2: Quantize with ITREX INT4
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${_MODEL_NAME}" "Step 2/3 — quantizing with ITREX WeightOnlyQuant INT4"

# shellcheck disable=SC2086
if ! ${_CMD_ITREX_QUANTIZE} 2>&1; then
    print_status "${STATUS_FAIL}" "${_MODEL_NAME}" "FAIL — ITREX quantization failed"
    exit 1
fi

print_status "${STATUS_PASS}" "${_MODEL_NAME}" "ITREX INT4 quantization complete"

# ---------------------------------------------------------------------------
# Step 3: Verify model loads with ITREX
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "${_MODEL_NAME}" "Step 3/3 — verifying model loads with ITREX"

# shellcheck disable=SC2086
if ! ${_CMD_ITREX_VERIFY} 2>&1; then
    print_status "${STATUS_FAIL}" "${_MODEL_NAME}" "FAIL — ITREX model verification failed"
    exit 1
fi

print_status "${STATUS_PASS}" "${_MODEL_NAME}" "ITREX model verification passed"

# ---------------------------------------------------------------------------
# Register in manifest
# ---------------------------------------------------------------------------
register_model "${_MODEL_NAME}" "${_BACKEND}" "${_OUTPUT_DIR}" "${_SIZE_GB}"

print_status "${STATUS_PASS}" "${_MODEL_NAME}" "PASS — INSTALLED (backend=${_BACKEND}, size=${_SIZE_GB}GB)"
exit 0
