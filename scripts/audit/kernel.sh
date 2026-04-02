#!/usr/bin/env bash
# scripts/audit/kernel.sh — Audit i915 kernel module parameters
# Part of OldIntelClaw audit suite (Story 1.5)
#
# Checks enable_guc and enable_fbc against recommended values for optimal
# Intel 11th Gen iGPU performance.
#
# Exit codes: always 0 (informational — never blocks the caller)
# Env var overrides for testing:
#   OLDINTELCLAW_SYSFS_GUC — path to enable_guc parameter file
#   OLDINTELCLAW_SYSFS_FBC — path to enable_fbc parameter file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

GUC_PATH="${OLDINTELCLAW_SYSFS_GUC:-/sys/module/i915/parameters/enable_guc}"
FBC_PATH="${OLDINTELCLAW_SYSFS_FBC:-/sys/module/i915/parameters/enable_fbc}"

# ---------------------------------------------------------------------------
# Guard: if either sysfs file is missing the i915 module is not loaded
# ---------------------------------------------------------------------------
if [[ ! -f "${GUC_PATH}" ]] || [[ ! -f "${FBC_PATH}" ]]; then
    print_status "${STATUS_WARN}" "kernel/i915" \
        "i915 module not loaded — cannot audit kernel parameters"
    exit 0
fi

# ---------------------------------------------------------------------------
# Read current values
# ---------------------------------------------------------------------------
guc_value="$(tr -d '[:space:]' < "${GUC_PATH}")"
fbc_value="$(tr -d '[:space:]' < "${FBC_PATH}")"

# ---------------------------------------------------------------------------
# enable_guc: recommended value is 3 (GuC + HuC firmware loading enabled)
# ---------------------------------------------------------------------------
if [[ "${guc_value}" == "3" ]]; then
    print_status "${STATUS_INFO}" "kernel/i915" \
        "enable_guc=${guc_value} — already optimal"
else
    print_status "${STATUS_WARN}" "kernel/i915" \
        "enable_guc=${guc_value} — recommend enable_guc=3 (GuC+HuC enabled)"
fi

# ---------------------------------------------------------------------------
# enable_fbc: recommended value is 1 (framebuffer compression enabled)
# ---------------------------------------------------------------------------
if [[ "${fbc_value}" == "1" ]]; then
    print_status "${STATUS_INFO}" "kernel/i915" \
        "enable_fbc=${fbc_value} — already optimal"
else
    print_status "${STATUS_WARN}" "kernel/i915" \
        "enable_fbc=${fbc_value} — recommend enable_fbc=1 (framebuffer compression)"
fi

exit 0
