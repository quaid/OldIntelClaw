#!/usr/bin/env bash
# scripts/install/openvino.sh — Install the OpenVINO Toolkit into a Python venv
# Part of the OldIntelClaw install suite (Story 2.2)
#
# Steps:
#   1. Create venv at VENV_DIR if it does not already exist
#   2. Check if openvino is already installed in the venv; skip if so
#   3. Install openvino and openvino-genai via pip
#   4. Verify the openvino import works
#   5. Verify a GPU device is available (WARN only — not a hard failure)
#
# Command overrides (for testing):
#   OLDINTELCLAW_CMD_OPENVINO_CHECK     — default: python3 -c "import openvino; ..."
#   OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK — default: python3 -c "from openvino import Core; ..."
#   OLDINTELCLAW_CMD_PIP_INSTALL        — default: pip install
#   OLDINTELCLAW_VENV_DIR               — default: ~/.oldintelclaw/venv
#   OLDINTELCLAW_CMD_VENV_CREATE        — default: python3 -m venv
#
# Dry-run support:
#   OLDINTELCLAW_DRY_RUN=1              — print what would be done; do not install
#
# Exit codes:
#   0 — openvino available (pre-installed or successfully installed)
#   1 — installation or import verification failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Command overrides
# ---------------------------------------------------------------------------
CMD_OPENVINO_CHECK="${OLDINTELCLAW_CMD_OPENVINO_CHECK:-python3 -c \"import openvino; print(openvino.__version__)\"}"
CMD_OPENVINO_GPU_CHECK="${OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK:-python3 -c \"from openvino import Core; devs=Core().available_devices; assert 'GPU' in devs\"}"
CMD_PIP_INSTALL="${OLDINTELCLAW_CMD_PIP_INSTALL:-pip install}"
VENV_DIR="${OLDINTELCLAW_VENV_DIR:-${HOME}/.oldintelclaw/venv}"
CMD_VENV_CREATE="${OLDINTELCLAW_CMD_VENV_CREATE:-python3 -m venv}"

DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

OPENVINO_PACKAGES="openvino openvino-genai"

# ---------------------------------------------------------------------------
# Dry-run early exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "venv"         "DRY RUN — would create venv at ${VENV_DIR} if missing"
    print_status "${STATUS_INFO}" "openvino"     "DRY RUN — would install ${OPENVINO_PACKAGES} if not present"
    print_status "${STATUS_INFO}" "openvino-genai" "DRY RUN — included in pip install above"
    print_status "${STATUS_INFO}" "GPU check"    "DRY RUN — would verify GPU device availability"
    print_status "${STATUS_INFO}" "Summary"      "DRY RUN complete — no changes made"
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 1: Create venv if it doesn't exist
# ---------------------------------------------------------------------------
if [[ -d "${VENV_DIR}" ]]; then
    print_status "${STATUS_INFO}" "venv" "SKIP — already exists at ${VENV_DIR}"
else
    print_status "${STATUS_INFO}" "venv" "Creating venv at ${VENV_DIR}"
    if ! eval "${CMD_VENV_CREATE}" "${VENV_DIR}" > /dev/null 2>&1; then
        print_status "${STATUS_FAIL}" "venv" "FAIL — could not create venv at ${VENV_DIR}"
        exit 1
    fi
    print_status "${STATUS_PASS}" "venv" "Created venv at ${VENV_DIR}"
fi

# ---------------------------------------------------------------------------
# Step 2: Check if openvino is already installed
# ---------------------------------------------------------------------------
if eval "${CMD_OPENVINO_CHECK}" > /dev/null 2>&1; then
    print_status "${STATUS_INFO}" "openvino" "SKIP — already installed"
    # Still run GPU check even if skipping install
    if eval "${CMD_OPENVINO_GPU_CHECK}" > /dev/null 2>&1; then
        print_status "${STATUS_PASS}" "GPU" "GPU device available"
    else
        print_status "${STATUS_WARN}" "GPU" "WARN — no GPU device detected (CPU-only mode)"
    fi
    print_status "${STATUS_INFO}" "Summary" "openvino ready"
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 3: Install openvino and openvino-genai
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "openvino" "Installing ${OPENVINO_PACKAGES} ..."
# shellcheck disable=SC2086
if ! eval "${CMD_PIP_INSTALL}" ${OPENVINO_PACKAGES} > /dev/null 2>&1; then
    print_status "${STATUS_FAIL}" "openvino" "FAIL — pip install failed for ${OPENVINO_PACKAGES}"
    exit 1
fi
print_status "${STATUS_PASS}" "openvino" "INSTALLED"
print_status "${STATUS_PASS}" "openvino-genai" "INSTALLED"

# ---------------------------------------------------------------------------
# Step 4: Check GPU availability (warn only — not a hard failure)
# ---------------------------------------------------------------------------
if eval "${CMD_OPENVINO_GPU_CHECK}" > /dev/null 2>&1; then
    print_status "${STATUS_PASS}" "GPU" "GPU device available"
else
    print_status "${STATUS_WARN}" "GPU" "WARN — no GPU device detected (CPU-only mode)"
fi

print_status "${STATUS_INFO}" "Summary" "openvino and openvino-genai ready"

exit 0
