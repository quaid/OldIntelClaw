#!/usr/bin/env bash
# scripts/install/rust.sh — Install Rust toolchain via rustup
# Part of the OldIntelClaw install suite (Story 2.4)
#
# Checks whether rustc and cargo are available. If either is missing,
# installs Rust via the official rustup installer. Verifies the install
# and warns if ~/.cargo/bin is not in PATH.
#
# Overridable environment variables (for testing):
#   OLDINTELCLAW_CMD_RUSTC_CHECK    — default: rustc --version
#   OLDINTELCLAW_CMD_CARGO_CHECK    — default: cargo --version
#   OLDINTELCLAW_CMD_RUSTUP_INSTALL — default: curl ... | sh (official rustup install)
#   OLDINTELCLAW_CMD_RUSTC_POST     — post-install rustc check (default: same as RUSTC_CHECK)
#   OLDINTELCLAW_CMD_CARGO_POST     — post-install cargo check (default: same as CARGO_CHECK)
#   OLDINTELCLAW_CMD_PATH_CHECK     — check if ~/.cargo/bin is in PATH (0 = missing)
#   OLDINTELCLAW_DRY_RUN            — set to 1 to print plan without installing
#
# Exit codes:
#   0 — Rust is available (already installed or freshly installed)
#   1 — install failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CMD_RUSTC_CHECK="${OLDINTELCLAW_CMD_RUSTC_CHECK:-rustc --version}"
CMD_CARGO_CHECK="${OLDINTELCLAW_CMD_CARGO_CHECK:-cargo --version}"
CMD_RUSTUP_INSTALL="${OLDINTELCLAW_CMD_RUSTUP_INSTALL:-curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y}"
CMD_PATH_CHECK="${OLDINTELCLAW_CMD_PATH_CHECK:-bash -c '[[ \":$PATH:\" == *\":$HOME/.cargo/bin:\"* ]]'}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Dry run header
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "rust-install" "DRY RUN — showing plan only, no changes will be made"
fi

# ---------------------------------------------------------------------------
# Check if Rust is already installed
# ---------------------------------------------------------------------------
rustc_ok=0
cargo_ok=0

if eval "${CMD_RUSTC_CHECK}" > /dev/null 2>&1; then
    rustc_ok=1
fi

if eval "${CMD_CARGO_CHECK}" > /dev/null 2>&1; then
    cargo_ok=1
fi

# ---------------------------------------------------------------------------
# Already installed — skip
# ---------------------------------------------------------------------------
if [[ "${rustc_ok}" -eq 1 && "${cargo_ok}" -eq 1 ]]; then
    rustc_ver="$(eval "${CMD_RUSTC_CHECK}" 2>&1)"
    cargo_ver="$(eval "${CMD_CARGO_CHECK}" 2>&1)"
    print_status "${STATUS_INFO}" "rust-install" "SKIP — rustc already installed: ${rustc_ver}"
    print_status "${STATUS_INFO}" "rust-install" "SKIP — cargo already installed: ${cargo_ver}"

    # PATH check even for already-installed Rust
    if ! eval "${CMD_PATH_CHECK}" > /dev/null 2>&1; then
        print_status "${STATUS_WARN}" "rust-install" \
            "WARN — ~/.cargo/bin is not in PATH; add it to your shell profile"
    fi

    exit 0
fi

# ---------------------------------------------------------------------------
# Dry run — print plan and exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "rust-install" "PLAN — would install Rust toolchain via rustup"
    print_status "${STATUS_INFO}" "rust-install" "PLAN — would verify rustc and cargo after install"
    exit 0
fi

# ---------------------------------------------------------------------------
# Install via rustup
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "rust-install" "Installing Rust toolchain via rustup..."

if ! eval "${CMD_RUSTUP_INSTALL}"; then
    print_status "${STATUS_FAIL}" "rust-install" "FAIL — rustup installer exited with an error"
    exit 1
fi

# ---------------------------------------------------------------------------
# Post-install verification
# ---------------------------------------------------------------------------
# Allow callers to provide separate post-install check commands so tests can
# simulate "not installed before, installed after" without real installation.
CMD_RUSTC_POST="${OLDINTELCLAW_CMD_RUSTC_POST:-${CMD_RUSTC_CHECK}}"
CMD_CARGO_POST="${OLDINTELCLAW_CMD_CARGO_POST:-${CMD_CARGO_CHECK}}"

rustc_ver=""
cargo_ver=""

if rustc_ver="$(eval "${CMD_RUSTC_POST}" 2>&1)"; then
    print_status "${STATUS_PASS}" "rust-install" "INSTALLED — rustc verified: ${rustc_ver}"
else
    print_status "${STATUS_FAIL}" "rust-install" "FAIL — rustc not found after install"
    exit 1
fi

if cargo_ver="$(eval "${CMD_CARGO_POST}" 2>&1)"; then
    print_status "${STATUS_PASS}" "rust-install" "INSTALLED — cargo verified: ${cargo_ver}"
else
    print_status "${STATUS_FAIL}" "rust-install" "FAIL — cargo not found after install"
    exit 1
fi

# ---------------------------------------------------------------------------
# PATH check
# ---------------------------------------------------------------------------
if ! eval "${CMD_PATH_CHECK}" > /dev/null 2>&1; then
    print_status "${STATUS_WARN}" "rust-install" \
        "WARN — ~/.cargo/bin is not in PATH; add it to your shell profile"
fi

exit 0
