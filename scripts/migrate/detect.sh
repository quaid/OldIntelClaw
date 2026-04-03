#!/usr/bin/env bash
# scripts/migrate/detect.sh — Detect existing OpenClaw workspace files
# Part of the OldIntelClaw migration suite (Story 3.3)
#
# Scans a colon-separated list of paths for OpenClaw files or directories.
# Reports findings and emits a machine-readable result line.
#
# Overridable environment variables:
#   OLDINTELCLAW_OPENCLAW_PATHS — colon-separated paths to scan
#                                 default: ${HOME}/.openclaw:./SKILL.md:./openclaw.yaml
#   OLDINTELCLAW_HOME           — default: ~/.oldintelclaw
#
# Exit code: always 0 — detection only, never fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
OPENCLAW_PATHS="${OLDINTELCLAW_OPENCLAW_PATHS:-${HOME}/.openclaw:./SKILL.md:./openclaw.yaml}"

# ---------------------------------------------------------------------------
# Scan each path in the colon-separated list
# ---------------------------------------------------------------------------
found_paths=()

# Use a temporary IFS to split on colons
IFS=':' read -ra path_list <<< "${OPENCLAW_PATHS}"

for candidate in "${path_list[@]}"; do
    # Expand tilde if present
    candidate="${candidate/#\~/$HOME}"

    if [[ -e "${candidate}" ]]; then
        found_paths+=("${candidate}")
    fi
done

# ---------------------------------------------------------------------------
# Report findings
# ---------------------------------------------------------------------------
if [[ "${#found_paths[@]}" -eq 0 ]]; then
    print_status "${STATUS_INFO}" "openclaw-detect" "No OpenClaw files detected"
    echo "OPENCLAW_FOUND=false"
else
    for found in "${found_paths[@]}"; do
        print_status "${STATUS_INFO}" "openclaw-detect" "Found: ${found}"
    done
    echo "OPENCLAW_FOUND=true"
fi

exit 0
