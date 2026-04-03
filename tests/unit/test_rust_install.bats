#!/usr/bin/env bats
# Unit tests for scripts/install/rust.sh — Story 2.4: Install Rust Toolchain
#
# Uses env var overrides for all external commands.
# The rustup installer mock writes a marker file to confirm it was called.

load '../test_helper'

RUST_SCRIPT="${SCRIPTS_DIR}/install/rust.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_INSTALL_MARKER="${TEST_TMPDIR}/rustup_called"

    # Default: rustc and cargo found (already installed)
    export OLDINTELCLAW_CMD_RUSTC_CHECK="echo rustc 1.75.0 (abc123 2024-01-01)"
    export OLDINTELCLAW_CMD_CARGO_CHECK="echo cargo 1.75.0 (xyz456 2024-01-01)"

    # Default: installer does nothing (shouldn't be reached when already installed)
    export OLDINTELCLAW_CMD_RUSTUP_INSTALL="true"

    # Default: ~/.cargo/bin is in PATH
    export OLDINTELCLAW_CMD_PATH_CHECK="true"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# Test 1: Rust already installed — SKIP, exits 0
# ---------------------------------------------------------------------------
@test "Rust already installed: SKIP, exits 0" {
    run "${RUST_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    # Installer must NOT have been called
    [ ! -f "${OLDINTELCLAW_INSTALL_MARKER}" ]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh install succeeds — INSTALLED, rustc+cargo verified, exits 0
# ---------------------------------------------------------------------------
@test "Fresh install succeeds: INSTALLED, rustc and cargo verified, exits 0" {
    # Simulate rustc/cargo missing before install, present after
    export OLDINTELCLAW_CMD_RUSTC_CHECK="false"
    export OLDINTELCLAW_CMD_CARGO_CHECK="false"

    # Installer succeeds and writes marker; post-install checks return success
    export OLDINTELCLAW_CMD_RUSTUP_INSTALL="touch ${OLDINTELCLAW_INSTALL_MARKER}"
    export OLDINTELCLAW_CMD_RUSTC_POST="echo rustc 1.75.0 (abc123 2024-01-01)"
    export OLDINTELCLAW_CMD_CARGO_POST="echo cargo 1.75.0 (xyz456 2024-01-01)"

    run "${RUST_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALLED"* ]]
    # Installer was called
    [ -f "${OLDINTELCLAW_INSTALL_MARKER}" ]
    # Output must confirm rustc and cargo are present
    [[ "$output" == *"rustc"* ]]
    [[ "$output" == *"cargo"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Install fails — FAIL, exits 1
# ---------------------------------------------------------------------------
@test "Install fails: FAIL status, exits 1" {
    export OLDINTELCLAW_CMD_RUSTC_CHECK="false"
    export OLDINTELCLAW_CMD_CARGO_CHECK="false"

    # Installer fails
    export OLDINTELCLAW_CMD_RUSTUP_INSTALL="false"
    # Post-install checks also fail (nothing was actually installed)
    export OLDINTELCLAW_CMD_RUSTC_POST="false"
    export OLDINTELCLAW_CMD_CARGO_POST="false"

    run "${RUST_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Rust installed but ~/.cargo/bin not in PATH — WARN about PATH
# ---------------------------------------------------------------------------
@test "Rust installed but cargo/bin not in PATH: WARN printed, exits 0" {
    # Rust is present
    export OLDINTELCLAW_CMD_RUSTC_CHECK="echo rustc 1.75.0"
    export OLDINTELCLAW_CMD_CARGO_CHECK="echo cargo 1.75.0"

    # But cargo/bin is not in PATH
    export OLDINTELCLAW_CMD_PATH_CHECK="false"

    run "${RUST_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]] || [[ "$output" == *"warn"* ]]
    [[ "$output" == *"PATH"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run mode — prints plan, no install
# ---------------------------------------------------------------------------
@test "Dry run mode: prints plan, no installer called" {
    export OLDINTELCLAW_CMD_RUSTC_CHECK="false"
    export OLDINTELCLAW_CMD_CARGO_CHECK="false"
    export OLDINTELCLAW_CMD_RUSTUP_INSTALL="touch ${OLDINTELCLAW_INSTALL_MARKER}"
    export OLDINTELCLAW_DRY_RUN="1"

    run "${RUST_SCRIPT}"

    [ "$status" -eq 0 ]
    # Must indicate dry run intent
    [[ "$output" == *"dry"* ]] || [[ "$output" == *"DRY"* ]] || [[ "$output" == *"plan"* ]] || [[ "$output" == *"PLAN"* ]]
    # Installer must NOT have been called
    [ ! -f "${OLDINTELCLAW_INSTALL_MARKER}" ]
}
