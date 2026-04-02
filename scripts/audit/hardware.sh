#!/usr/bin/env bash
# hardware.sh — RAM and iGPU availability check
# Part of OldIntelClaw audit suite

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# RAM check
# Reads from OLDINTELCLAW_MEMINFO (defaults to /proc/meminfo)
# PASS: >= 15 GB, WARN: 12–15 GB, FAIL: < 12 GB
# ---------------------------------------------------------------------------
check_ram() {
    local meminfo_path="${OLDINTELCLAW_MEMINFO:-/proc/meminfo}"

    if [[ ! -f "$meminfo_path" ]]; then
        print_status "$STATUS_FAIL" "RAM" "Cannot read meminfo: $meminfo_path not found"
        return 1
    fi

    local mem_kb
    mem_kb=$(grep -m1 '^MemTotal:' "$meminfo_path" | awk '{print $2}')

    if [[ -z "$mem_kb" ]]; then
        print_status "$STATUS_FAIL" "RAM" "MemTotal not found in $meminfo_path"
        return 1
    fi

    # Convert kB to GB (integer, rounded down)
    local mem_gb=$(( mem_kb / 1024 / 1024 ))

    if (( mem_gb >= 15 )); then
        print_status "$STATUS_PASS" "RAM" "${mem_gb}GB detected (recommended: 16GB)"
        return 0
    elif (( mem_gb >= 12 )); then
        print_status "$STATUS_WARN" "RAM" "${mem_gb}GB detected (below recommended 16GB, may work)"
        return 0
    else
        print_status "$STATUS_FAIL" "RAM" "${mem_gb}GB detected (minimum 12GB required)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# iGPU check
# Uses OLDINTELCLAW_LSPCI_OUTPUT env var if set, otherwise runs lspci -nn
# Looks for "Intel" combined with "Iris" or "Xe" in the output
# ---------------------------------------------------------------------------
check_igpu() {
    local lspci_output
    if [[ -n "${OLDINTELCLAW_LSPCI_OUTPUT:-}" ]]; then
        lspci_output="$OLDINTELCLAW_LSPCI_OUTPUT"
    else
        lspci_output="$(lspci -nn 2>/dev/null)"
    fi

    if echo "$lspci_output" | grep -qiE 'Intel.*(Iris|Xe)'; then
        local gpu_line
        gpu_line=$(echo "$lspci_output" | grep -iE 'Intel.*(Iris|Xe)' | head -1)
        print_status "$STATUS_PASS" "iGPU" "$gpu_line"
        return 0
    else
        print_status "$STATUS_FAIL" "iGPU" "No Intel Iris/Xe GPU detected in lspci output"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Render device check
# Checks for DRI render node at OLDINTELCLAW_DRI_RENDER (default /dev/dri/renderD128)
# PASS if exists, WARN if missing
# ---------------------------------------------------------------------------
check_render_device() {
    local render_path="${OLDINTELCLAW_DRI_RENDER:-/dev/dri/renderD128}"

    if [[ -e "$render_path" ]]; then
        print_status "$STATUS_PASS" "render device" "$render_path is accessible"
        return 0
    else
        print_status "$STATUS_WARN" "render device" "$render_path not found (GPU acceleration may be unavailable)"
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    local exit_code=0

    check_ram    || exit_code=1
    check_igpu   || exit_code=1
    check_render_device || exit_code=1

    exit "$exit_code"
}

main
