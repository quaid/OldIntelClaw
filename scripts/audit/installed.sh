#!/usr/bin/env bash
# scripts/audit/installed.sh — Detect which components are already installed
# Part of the OldIntelClaw audit suite (Story 1.4)
#
# Checks: OpenVINO, Rust, ZeroClaw, Python 3.12+, ITREX
#
# Each check command can be overridden via env vars for testing:
#   OLDINTELCLAW_CMD_OPENVINO        — default: python3 -c "import openvino"
#   OLDINTELCLAW_CMD_RUST            — default: rustc --version
#   OLDINTELCLAW_CMD_ZEROCLAW        — default: zeroclaw --version
#   OLDINTELCLAW_CMD_PYTHON          — default: python3 --version
#   OLDINTELCLAW_CMD_PYTHON_VERSION  — command whose stdout is parsed for version
#   OLDINTELCLAW_CMD_ITREX           — default: python3 -c "import intel_extension_for_transformers"
#
# Exit code: always 0 — this script is informational only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Component check commands (overridable via env vars)
# ---------------------------------------------------------------------------
CMD_OPENVINO="${OLDINTELCLAW_CMD_OPENVINO:-python3 -c \"import openvino\"}"
CMD_RUST="${OLDINTELCLAW_CMD_RUST:-rustc --version}"
CMD_ZEROCLAW="${OLDINTELCLAW_CMD_ZEROCLAW:-zeroclaw --version}"
CMD_PYTHON="${OLDINTELCLAW_CMD_PYTHON:-python3 --version}"
CMD_PYTHON_VERSION="${OLDINTELCLAW_CMD_PYTHON_VERSION:-python3 --version}"
CMD_ITREX="${OLDINTELCLAW_CMD_ITREX:-python3 -c \"import intel_extension_for_transformers\"}"

# Minimum required Python version
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=12

# ---------------------------------------------------------------------------
# check_component LABEL CMD
#   Runs CMD silently; prints INSTALLED or MISSING status line.
#   Returns 0 if installed, 1 if missing.
# ---------------------------------------------------------------------------
check_component() {
    local label="$1"
    local cmd="$2"

    if eval "$cmd" > /dev/null 2>&1; then
        print_status "${STATUS_PASS}" "${label}" "INSTALLED"
        return 0
    else
        print_status "${STATUS_INFO}" "${label}" "MISSING"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# check_python
#   Two-stage check:
#     1. Is python3 present at all? (CMD_PYTHON)
#     2. Is the version >= 3.12?    (CMD_PYTHON_VERSION)
#   Prints one status line for "Python" (binary) and one for "Python version".
#   Returns 0 only if both checks pass.
# ---------------------------------------------------------------------------
check_python() {
    # Stage 1: binary present?
    if ! eval "$CMD_PYTHON" > /dev/null 2>&1; then
        print_status "${STATUS_INFO}" "Python" "MISSING"
        print_status "${STATUS_INFO}" "Python version" "MISSING (no python3 found)"
        return 1
    fi

    print_status "${STATUS_PASS}" "Python" "INSTALLED"

    # Stage 2: parse version from CMD_PYTHON_VERSION output
    local version_output
    version_output="$(eval "$CMD_PYTHON_VERSION" 2>&1)" || {
        print_status "${STATUS_WARN}" "Python version" "WARN — could not determine version"
        return 1
    }

    # Extract "X.Y" from "Python X.Y.Z"
    local major minor
    if [[ "$version_output" =~ Python[[:space:]]+([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
    else
        print_status "${STATUS_WARN}" "Python version" "WARN — unrecognised version string: ${version_output}"
        return 1
    fi

    if (( major > PYTHON_MIN_MAJOR )) || \
       (( major == PYTHON_MIN_MAJOR && minor >= PYTHON_MIN_MINOR )); then
        print_status "${STATUS_PASS}" "Python version" "INSTALLED (${major}.${minor} >= ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR})"
        return 0
    else
        print_status "${STATUS_WARN}" "Python version" \
            "WARN — ${major}.${minor} found, ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR}+ required"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
installed_count=0
total_components=5

# OpenVINO
if check_component "OpenVINO" "${CMD_OPENVINO}"; then
    (( installed_count++ )) || true
fi

# Rust
if check_component "Rust" "${CMD_RUST}"; then
    (( installed_count++ )) || true
fi

# ZeroClaw
if check_component "ZeroClaw" "${CMD_ZEROCLAW}"; then
    (( installed_count++ )) || true
fi

# Python (counts only when binary present AND version >= 3.12)
if check_python; then
    (( installed_count++ )) || true
fi

# ITREX
if check_component "ITREX" "${CMD_ITREX}"; then
    (( installed_count++ )) || true
fi

# Summary
print_status "${STATUS_INFO}" "Summary" "${installed_count}/${total_components} components installed"

exit 0
