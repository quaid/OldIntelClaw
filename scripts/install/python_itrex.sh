#!/usr/bin/env bash
# scripts/install/python_itrex.sh — Install Python virtualenv and ITREX
# Part of the OldIntelClaw install suite (Story 2.5)
#
# Checks Python 3.12+, creates a virtualenv, and installs
# intel-extension-for-transformers (ITREX) with its dependencies.
#
# All external commands and paths can be overridden via env vars for testing:
#   OLDINTELCLAW_CMD_PYTHON_CHECK   — default: python3 --version
#   OLDINTELCLAW_CMD_PYTHON_VERSION — default: python3 --version (parsed for X.Y)
#   OLDINTELCLAW_CMD_ITREX_CHECK    — default: python3 -c "import intel_extension_for_transformers"
#   OLDINTELCLAW_CMD_ITREX_VERIFY   — default: same as ITREX_CHECK (post-install import verify)
#   OLDINTELCLAW_CMD_VENV_CREATE    — default: python3 -m venv
#   OLDINTELCLAW_CMD_PIP_INSTALL    — default: pip install
#   OLDINTELCLAW_VENV_DIR           — default: ~/.oldintelclaw/venv
#   OLDINTELCLAW_DRY_RUN            — set to "1" to print plan without installing
#
# Exit codes:
#   0 — success (all installed or already present)
#   1 — failure (Python version gate, pip error, or ITREX verify failure)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Overridable commands and paths
# ---------------------------------------------------------------------------
CMD_PYTHON_CHECK="${OLDINTELCLAW_CMD_PYTHON_CHECK:-python3 --version}"
CMD_PYTHON_VERSION="${OLDINTELCLAW_CMD_PYTHON_VERSION:-python3 --version}"
CMD_ITREX_CHECK="${OLDINTELCLAW_CMD_ITREX_CHECK:-python3 -c \"import intel_extension_for_transformers\"}"
# Post-install verification — defaults to the same check as CMD_ITREX_CHECK
CMD_ITREX_VERIFY="${OLDINTELCLAW_CMD_ITREX_VERIFY:-${CMD_ITREX_CHECK}}"
CMD_VENV_CREATE="${OLDINTELCLAW_CMD_VENV_CREATE:-python3 -m venv}"
CMD_PIP_INSTALL="${OLDINTELCLAW_CMD_PIP_INSTALL:-pip install}"
VENV_DIR="${OLDINTELCLAW_VENV_DIR:-${HOME}/.oldintelclaw/venv}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# Minimum required Python version
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=12

# ---------------------------------------------------------------------------
# dry_run_mode
#   If DRY_RUN=1, print the plan and exit 0 without performing any install.
# ---------------------------------------------------------------------------
dry_run_mode() {
    if [[ "${DRY_RUN}" == "1" ]]; then
        print_status "${STATUS_INFO}" "Dry-run plan" "PLAN: check Python 3.12+, create venv at ${VENV_DIR}, install ITREX"
        print_status "${STATUS_INFO}" "Dry-run plan" "PLAN: pip install intel-extension-for-transformers transformers torch optimum-intel"
        print_status "${STATUS_INFO}" "Dry-run plan" "PLAN: verify ITREX import — no changes made"
        exit 0
    fi
}

# ---------------------------------------------------------------------------
# check_python
#   Validates Python 3.12+ is available.
#   Prints status lines and returns 0 on success, exits 1 on failure.
# ---------------------------------------------------------------------------
check_python() {
    # Stage 1: is python3 binary present?
    if ! eval "$CMD_PYTHON_CHECK" > /dev/null 2>&1; then
        print_status "${STATUS_FAIL}" "Python" "FAIL — python3 not found"
        exit 1
    fi

    # Stage 2: parse version from CMD_PYTHON_VERSION output
    local version_output
    version_output="$(eval "$CMD_PYTHON_VERSION" 2>&1)" || {
        print_status "${STATUS_FAIL}" "Python version" "FAIL — could not determine version"
        exit 1
    }

    local major minor
    if [[ "$version_output" =~ Python[[:space:]]+([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
    else
        print_status "${STATUS_FAIL}" "Python version" "FAIL — unrecognised version string: ${version_output}"
        exit 1
    fi

    if (( major > PYTHON_MIN_MAJOR )) || \
       (( major == PYTHON_MIN_MAJOR && minor >= PYTHON_MIN_MINOR )); then
        print_status "${STATUS_PASS}" "Python version" \
            "OK — ${major}.${minor} >= ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR}"
        return 0
    else
        print_status "${STATUS_FAIL}" "Python version" \
            "FAIL — ${major}.${minor} found, ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR}+ required"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# ensure_venv
#   Creates the virtualenv at VENV_DIR if it does not already exist.
# ---------------------------------------------------------------------------
ensure_venv() {
    if [[ -d "${VENV_DIR}" ]]; then
        print_status "${STATUS_INFO}" "Virtualenv" "EXISTS — ${VENV_DIR}"
        return 0
    fi

    print_status "${STATUS_INFO}" "Virtualenv" "CREATING — ${VENV_DIR}"
    if ! eval "${CMD_VENV_CREATE} ${VENV_DIR}" > /dev/null 2>&1; then
        print_status "${STATUS_FAIL}" "Virtualenv" "FAIL — could not create venv at ${VENV_DIR}"
        exit 1
    fi
    print_status "${STATUS_PASS}" "Virtualenv" "CREATED — ${VENV_DIR}"
}

# ---------------------------------------------------------------------------
# install_itrex
#   Checks if ITREX is already installed; skips if so.
#   Otherwise runs pip install and verifies the import.
# ---------------------------------------------------------------------------
install_itrex() {
    # Check if already installed
    if eval "$CMD_ITREX_CHECK" > /dev/null 2>&1; then
        print_status "${STATUS_INFO}" "ITREX" "SKIP — already installed"
        return 0
    fi

    print_status "${STATUS_INFO}" "ITREX" "INSTALLING — intel-extension-for-transformers + deps"

    local packages="intel-extension-for-transformers transformers torch optimum-intel"
    if ! eval "${CMD_PIP_INSTALL} ${packages}" > /dev/null 2>&1; then
        print_status "${STATUS_FAIL}" "ITREX" "FAIL — pip install failed"
        exit 1
    fi

    # Verify import works after install (uses CMD_ITREX_VERIFY, separate from pre-check)
    if ! eval "$CMD_ITREX_VERIFY" > /dev/null 2>&1; then
        print_status "${STATUS_FAIL}" "ITREX" "FAIL — installed but import verification failed"
        exit 1
    fi

    print_status "${STATUS_PASS}" "ITREX" "INSTALLED — intel-extension-for-transformers"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
dry_run_mode
check_python
ensure_venv
install_itrex

exit 0
