#!/usr/bin/env bash
# scripts/install/gpu_access.sh — Configure iGPU access for current user
# Part of the OldIntelClaw install suite (Story 2.3)
#
# Adds the current user to the `video` and `render` groups required for
# Intel iGPU access via OpenCL/VAAPI/DRI. Idempotent: skips groups the
# user already belongs to.
#
# Overridable environment variables (for testing):
#   OLDINTELCLAW_CMD_ID_GROUPS  — default: id -nG  (list current user groups)
#   OLDINTELCLAW_CMD_USERMOD    — default: sudo usermod -aG
#   OLDINTELCLAW_CMD_IS_ROOT    — override root check: 1 = root, 0 = not root
#   OLDINTELCLAW_CMD_WHOAMI     — default: whoami
#   OLDINTELCLAW_DRY_RUN        — set to 1 to print plan without making changes
#
# Exit codes:
#   0 — success (groups added or already present)
#   1 — not running as root/sudo

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CMD_ID_GROUPS="${OLDINTELCLAW_CMD_ID_GROUPS:-id -nG}"
CMD_USERMOD="${OLDINTELCLAW_CMD_USERMOD:-sudo usermod -aG}"
CMD_WHOAMI="${OLDINTELCLAW_CMD_WHOAMI:-whoami}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

IGPU_GROUPS=("video" "render")

# ---------------------------------------------------------------------------
# Root check
# ---------------------------------------------------------------------------
is_root() {
    if [[ -n "${OLDINTELCLAW_CMD_IS_ROOT:-}" ]]; then
        [[ "${OLDINTELCLAW_CMD_IS_ROOT}" == "1" ]]
    else
        [[ "${EUID}" -eq 0 ]]
    fi
}

if ! is_root; then
    print_status "${STATUS_FAIL}" "gpu-access" "Must be run as root or with sudo"
    exit 1
fi

# ---------------------------------------------------------------------------
# Dry run header
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "gpu-access" "DRY RUN — showing plan only, no changes will be made"
fi

# ---------------------------------------------------------------------------
# Get current user and group membership
# ---------------------------------------------------------------------------
current_user="$(eval "${CMD_WHOAMI}")"
current_groups="$(eval "${CMD_ID_GROUPS}")"

# ---------------------------------------------------------------------------
# Process each required group
# ---------------------------------------------------------------------------
groups_added=0

for group in "${IGPU_GROUPS[@]}"; do
    if echo "${current_groups}" | tr ' ' '\n' | grep -qx "${group}"; then
        print_status "${STATUS_INFO}" "gpu-access" "${group}: SKIP — ${current_user} already a member"
    else
        if [[ "${DRY_RUN}" == "1" ]]; then
            print_status "${STATUS_INFO}" "gpu-access" "${group}: PLAN — would add ${current_user} to ${group}"
        else
            eval "${CMD_USERMOD} ${group} ${current_user}"
            print_status "${STATUS_PASS}" "gpu-access" "${group}: ADDED — ${current_user} added to ${group}"
            (( groups_added++ )) || true
        fi
    fi
done

# ---------------------------------------------------------------------------
# Logout warning (only when groups were actually added)
# ---------------------------------------------------------------------------
if [[ "${groups_added}" -gt 0 ]]; then
    print_status "${STATUS_WARN}" "gpu-access" \
        "Groups added — logout and re-login for changes to take effect"
fi

exit 0
