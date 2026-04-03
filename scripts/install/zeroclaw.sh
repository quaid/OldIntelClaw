#!/usr/bin/env bash
# scripts/install/zeroclaw.sh — Build and install ZeroClaw via cargo
# Part of the OldIntelClaw install suite (Story 3.1)
#
# Checks whether ZeroClaw is already installed. If not, installs it via
# cargo and verifies the binary works post-install. Creates the
# OLDINTELCLAW_HOME directory if it does not already exist.
#
# Overridable environment variables (for testing):
#   OLDINTELCLAW_CMD_ZEROCLAW_CHECK   — default: zeroclaw --version
#   OLDINTELCLAW_CMD_CARGO_INSTALL    — default: cargo install zeroclaw
#   OLDINTELCLAW_CMD_ZEROCLAW_POST    — default: zeroclaw --version (post-install verify)
#   OLDINTELCLAW_HOME                 — default: ~/.oldintelclaw
#   OLDINTELCLAW_DRY_RUN              — set to 1 to print plan without installing
#
# Exit codes:
#   0 — ZeroClaw is available (already installed or freshly installed)
#   1 — install failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CMD_ZEROCLAW_CHECK="${OLDINTELCLAW_CMD_ZEROCLAW_CHECK:-zeroclaw --version}"
CMD_CARGO_INSTALL="${OLDINTELCLAW_CMD_CARGO_INSTALL:-cargo install zeroclaw}"
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Dry run header
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "zeroclaw-install" "DRY RUN — showing plan only, no changes will be made"
fi

# ---------------------------------------------------------------------------
# Check if ZeroClaw is already installed
# ---------------------------------------------------------------------------
if eval "${CMD_ZEROCLAW_CHECK}" > /dev/null 2>&1; then
    zeroclaw_ver="$(eval "${CMD_ZEROCLAW_CHECK}" 2>&1)"
    print_status "${STATUS_INFO}" "zeroclaw-install" "SKIP — zeroclaw already installed: ${zeroclaw_ver}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Dry run — print plan and exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "zeroclaw-install" "PLAN — would run: ${CMD_CARGO_INSTALL}"
    print_status "${STATUS_INFO}" "zeroclaw-install" "PLAN — would verify zeroclaw binary after install"
    print_status "${STATUS_INFO}" "zeroclaw-install" "PLAN — would create ${OLDINTELCLAW_HOME} if missing"
    exit 0
fi

# ---------------------------------------------------------------------------
# Install via cargo
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "zeroclaw-install" "Installing ZeroClaw via cargo..."

if ! eval "${CMD_CARGO_INSTALL}"; then
    print_status "${STATUS_FAIL}" "zeroclaw-install" "FAIL — cargo install exited with an error"
    exit 1
fi

# ---------------------------------------------------------------------------
# Post-install verification
# ---------------------------------------------------------------------------
CMD_ZEROCLAW_POST="${OLDINTELCLAW_CMD_ZEROCLAW_POST:-${CMD_ZEROCLAW_CHECK}}"

if zeroclaw_ver="$(eval "${CMD_ZEROCLAW_POST}" 2>&1)"; then
    print_status "${STATUS_PASS}" "zeroclaw-install" "INSTALLED — zeroclaw verified: ${zeroclaw_ver}"
else
    print_status "${STATUS_FAIL}" "zeroclaw-install" "FAIL — zeroclaw not found after install"
    exit 1
fi

# ---------------------------------------------------------------------------
# Create OLDINTELCLAW_HOME directory if it does not exist
# ---------------------------------------------------------------------------
if [[ ! -d "${OLDINTELCLAW_HOME}" ]]; then
    mkdir -p "${OLDINTELCLAW_HOME}"
    print_status "${STATUS_PASS}" "zeroclaw-install" "Created ${OLDINTELCLAW_HOME}"
fi

exit 0
