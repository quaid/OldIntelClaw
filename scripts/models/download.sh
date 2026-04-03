#!/usr/bin/env bash
# scripts/models/download.sh — Model Download Engine library
# Part of the OldIntelClaw model management suite (Story 4.2)
#
# Provides three functions sourced by individual model install scripts:
#
#   download_model MODEL_NAME HF_REPO OUTPUT_DIR [EXPECTED_SHA256]
#   register_model MODEL_NAME BACKEND PATH SIZE_GB
#   check_model_exists MODEL_NAME
#
# Command overrides (for testing):
#   OLDINTELCLAW_CMD_DOWNLOAD   — default: curl -L -C - --progress-bar -o
#                                 Called as: $CMD_DOWNLOAD <output_file> <url>
#   OLDINTELCLAW_CMD_CHECKSUM   — default: sha256sum
#                                 Called as: $CMD_CHECKSUM <file>; first field of output is the hash
#   OLDINTELCLAW_HOME           — default: ~/.oldintelclaw
#
# Dry-run support:
#   OLDINTELCLAW_DRY_RUN=1      — print what would be done; do not download
#
# Exit codes (for download_model):
#   0 — model available (pre-registered, dry-run, or successfully downloaded+verified)
#   1 — download failed or checksum mismatch

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# Hugging Face base URL for model downloads (constant — never overridden)
readonly _HF_BASE="https://huggingface.co"

# ---------------------------------------------------------------------------
# check_model_exists MODEL_NAME
# Returns 0 if model is already registered in manifest.json, 1 if not.
# ---------------------------------------------------------------------------
check_model_exists() {
    local model_name="$1"
    local manifest="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}/manifest.json"

    if [[ ! -f "${manifest}" ]]; then
        return 1
    fi

    grep -q "\"${model_name}\"" "${manifest}"
}

# ---------------------------------------------------------------------------
# register_model MODEL_NAME BACKEND PATH SIZE_GB
# Adds a model entry to manifest.json. Creates the file if missing.
# ---------------------------------------------------------------------------
register_model() {
    local model_name="$1"
    local backend="$2"
    local model_path="$3"
    local size_gb="$4"
    local manifest="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}/manifest.json"
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Ensure home dir and manifest exist
    mkdir -p "$(dirname "${manifest}")"
    if [[ ! -f "${manifest}" ]]; then
        printf '{\n  "models": {}\n}\n' > "${manifest}"
    fi

    # Build the JSON entry for this model.
    # We use sed to insert before the closing "}" of the "models" block.
    # This avoids requiring jq as a dependency.
    local entry
    entry="    \"${model_name}\": {\n      \"backend\": \"${backend}\",\n      \"path\": \"${model_path}\",\n      \"size_gb\": \"${size_gb}\",\n      \"registered\": \"${timestamp}\"\n    }"

    # Check if models block already has entries (i.e., is non-empty).
    # We look for anything between "models": { and the closing }
    if grep -q '"models": {}' "${manifest}"; then
        # Empty models block — replace the {} with the entry
        sed -i "s|\"models\": {}|\"models\": {\n${entry}\n  }|" "${manifest}"
    else
        # Non-empty models block — insert before the final closing } of models
        # Append a comma after the last entry, then add the new entry before closing brace.
        # Strategy: find the last } that closes the models object and insert before it.
        sed -i "/^  }$/{
            s|^  }$|,\n${entry}\n  }|
        }" "${manifest}"
    fi

    print_status "${STATUS_PASS}" "manifest" "Registered ${model_name} (${backend}, ${size_gb}GB)"
}

# ---------------------------------------------------------------------------
# download_model MODEL_NAME HF_REPO OUTPUT_DIR [EXPECTED_SHA256]
# Downloads a model from Hugging Face, verifies checksum if provided.
# Returns 0 on success, 1 on failure.
# ---------------------------------------------------------------------------
download_model() {
    local model_name="$1"
    local hf_repo="$2"
    local output_dir="$3"
    local expected_sha256="${4:-}"

    # Resolve env vars at call time so subshell tests pick up overrides correctly
    local cmd_download="${OLDINTELCLAW_CMD_DOWNLOAD:-curl -L -C - --progress-bar -o}"
    local cmd_checksum="${OLDINTELCLAW_CMD_CHECKSUM:-sha256sum}"
    local dry_run="${OLDINTELCLAW_DRY_RUN:-0}"

    # ------------------------------------------------------------------
    # Dry-run early exit
    # ------------------------------------------------------------------
    if [[ "${dry_run}" == "1" ]]; then
        print_status "${STATUS_INFO}" "${model_name}" "DRY RUN — would download from ${_HF_BASE}/${hf_repo}"
        print_status "${STATUS_INFO}" "${model_name}" "DRY RUN — output dir: ${output_dir}"
        if [[ -n "${expected_sha256}" ]]; then
            print_status "${STATUS_INFO}" "${model_name}" "DRY RUN — would verify SHA256: ${expected_sha256}"
        fi
        print_status "${STATUS_INFO}" "${model_name}" "DRY RUN complete — no changes made"
        return 0
    fi

    # ------------------------------------------------------------------
    # Skip if already registered
    # ------------------------------------------------------------------
    if check_model_exists "${model_name}"; then
        print_status "${STATUS_INFO}" "${model_name}" "SKIP — already registered in manifest"
        return 0
    fi

    # ------------------------------------------------------------------
    # Ensure output directory exists
    # ------------------------------------------------------------------
    mkdir -p "${output_dir}"

    # ------------------------------------------------------------------
    # Build download target
    # The output file is a sentinel that represents the downloaded model.
    # For HF repos the real download would be the full repo directory;
    # here we write a single file as a placeholder / progress artifact.
    # ------------------------------------------------------------------
    local output_file="${output_dir}/${model_name}.bin"
    local hf_url="${_HF_BASE}/${hf_repo}/resolve/main/${model_name}.bin"

    print_status "${STATUS_INFO}" "${model_name}" "Downloading from ${hf_url} ..."

    # cmd_download is: <cmd> <output_file> <url>
    # e.g.: curl -L -C - --progress-bar -o <output_file> <url>
    # shellcheck disable=SC2086
    if ! ${cmd_download} "${output_file}" "${hf_url}" 2>&1; then
        print_status "${STATUS_FAIL}" "${model_name}" "FAIL — download command failed"
        return 1
    fi

    # ------------------------------------------------------------------
    # Checksum verification (optional)
    # ------------------------------------------------------------------
    if [[ -n "${expected_sha256}" ]]; then
        print_status "${STATUS_INFO}" "${model_name}" "Verifying SHA256 checksum ..."

        local actual_sha256
        # shellcheck disable=SC2086
        actual_sha256=$(${cmd_checksum} "${output_file}" 2>/dev/null | awk '{print $1}')

        if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
            print_status "${STATUS_FAIL}" "${model_name}" \
                "FAIL — checksum mismatch (expected: ${expected_sha256}, got: ${actual_sha256})"
            return 1
        fi

        print_status "${STATUS_PASS}" "${model_name}" "Checksum verified"
    fi

    print_status "${STATUS_PASS}" "${model_name}" "PASS — download complete"
    return 0
}
