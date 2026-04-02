#!/usr/bin/env bash
# scripts/audit/kernel_optimize.sh — Optionally configure i915 kernel parameters
# Part of the OldIntelClaw audit suite (Story 1.6)
#
# Writes /etc/modprobe.d/i915.conf and regenerates initramfs.
# Requires root. Exits 1 if not running as root.
#
# Overridable environment variables (for testing):
#   OLDINTELCLAW_MODPROBE_DIR  — directory for modprobe config (default: /etc/modprobe.d)
#   OLDINTELCLAW_DRACUT_CMD    — initramfs regeneration command (default: dracut -f)
#   OLDINTELCLAW_IS_ROOT       — override root check: 1 = root, 0 = not root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Root check
# ---------------------------------------------------------------------------
is_root() {
    if [[ -n "${OLDINTELCLAW_IS_ROOT:-}" ]]; then
        [[ "${OLDINTELCLAW_IS_ROOT}" == "1" ]]
    else
        [[ "${EUID}" -eq 0 ]]
    fi
}

if ! is_root; then
    print_status "${STATUS_FAIL}" "kernel-optimize" "Must be run as root or with sudo"
    exit 1
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
modprobe_dir="${OLDINTELCLAW_MODPROBE_DIR:-/etc/modprobe.d}"
conf_file="${modprobe_dir}/i915.conf"
dracut_cmd="${OLDINTELCLAW_DRACUT_CMD:-dracut -f}"
i915_options="options i915 enable_guc=3 enable_fbc=1"

# ---------------------------------------------------------------------------
# Backup existing config if present
# ---------------------------------------------------------------------------
if [[ -f "${conf_file}" ]]; then
    backup_file="${conf_file}.bak.$(date +%s)"
    cp "${conf_file}" "${backup_file}"
    print_status "${STATUS_INFO}" "kernel-optimize" "Existing config backed up to ${backup_file}"
fi

# ---------------------------------------------------------------------------
# Write new i915 config
# ---------------------------------------------------------------------------
printf '%s\n' "${i915_options}" > "${conf_file}"

print_status "${STATUS_PASS}" "kernel-optimize" "i915 parameters written to ${conf_file}"

# ---------------------------------------------------------------------------
# Regenerate initramfs
# ---------------------------------------------------------------------------
${dracut_cmd}

# ---------------------------------------------------------------------------
# Reboot warning
# ---------------------------------------------------------------------------
print_status "${STATUS_WARN}" "kernel-optimize" "A reboot is required for changes to take effect"

exit 0
