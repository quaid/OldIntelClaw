#!/usr/bin/env bash
# scripts/install/intel_packages.sh — Install Intel system packages
# Part of the OldIntelClaw install suite (Story 2.1)
#
# Packages installed: intel-compute-runtime, intel-level-zero-gpu,
#                     level-zero, intel-media-driver
#
# Each step command can be overridden via env vars for testing:
#   OLDINTELCLAW_CMD_RPM_QUERY   — default: rpm -q
#   OLDINTELCLAW_CMD_DNF_INSTALL — default: sudo dnf install -y
#   OLDINTELCLAW_CMD_IS_ROOT     — override root check (exit 0 = root)
#
# Dry-run support:
#   OLDINTELCLAW_DRY_RUN=1       — print what would be done; do not install
#
# Exit codes:
#   0 — all packages available (pre-installed or successfully installed)
#   1 — one or more packages could not be installed, or not running as root

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Command overrides
# ---------------------------------------------------------------------------
CMD_RPM_QUERY="${OLDINTELCLAW_CMD_RPM_QUERY:-rpm -q}"
CMD_DNF_INSTALL="${OLDINTELCLAW_CMD_DNF_INSTALL:-sudo dnf install -y}"
CMD_IS_ROOT="${OLDINTELCLAW_CMD_IS_ROOT:-}"

DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Package list
# ---------------------------------------------------------------------------
PACKAGES=(
    intel-compute-runtime
    intel-level-zero-gpu
    level-zero
    intel-media-driver
)

TOTAL_PACKAGES="${#PACKAGES[@]}"

# ---------------------------------------------------------------------------
# is_root — return 0 if we have sufficient privilege to install
# ---------------------------------------------------------------------------
is_root() {
    if [[ -n "${CMD_IS_ROOT}" ]]; then
        eval "${CMD_IS_ROOT}"
        return $?
    fi
    [[ "${EUID}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# is_package_installed PKG
#   Returns 0 if the package is already installed, 1 otherwise.
# ---------------------------------------------------------------------------
is_package_installed() {
    local pkg="$1"
    eval "${CMD_RPM_QUERY}" "${pkg}" > /dev/null 2>&1
}

# ---------------------------------------------------------------------------
# install_package PKG
#   Installs a single package; returns 0 on success, 1 on failure.
# ---------------------------------------------------------------------------
install_package() {
    local pkg="$1"
    eval "${CMD_DNF_INSTALL}" "${pkg}" > /dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Root check — must come before anything that modifies the system
if ! is_root; then
    print_status "${STATUS_FAIL}" "Root check" "Must be run as root (or with sudo). Aborting."
    exit 1
fi

ready_count=0
failed=0

for pkg in "${PACKAGES[@]}"; do
    if [[ "${DRY_RUN}" == "1" ]]; then
        print_status "${STATUS_INFO}" "${pkg}" "DRY RUN — would install if missing"
        continue
    fi

    if is_package_installed "${pkg}"; then
        print_status "${STATUS_INFO}" "${pkg}" "SKIP — already installed"
        (( ready_count++ )) || true
    else
        if install_package "${pkg}"; then
            print_status "${STATUS_PASS}" "${pkg}" "INSTALLED"
            (( ready_count++ )) || true
        else
            print_status "${STATUS_FAIL}" "${pkg}" "FAIL — install failed"
            (( failed++ )) || true
        fi
    fi
done

# Summary
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "Summary" "DRY RUN — ${TOTAL_PACKAGES} packages would be processed"
    exit 0
fi

print_status "${STATUS_INFO}" "Summary" "${ready_count}/${TOTAL_PACKAGES} packages ready"

if [[ "${failed}" -gt 0 ]]; then
    exit 1
fi

exit 0
