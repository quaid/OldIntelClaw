#!/usr/bin/env bats
# Unit tests for scripts/install/zeroclaw.sh — Story 3.1: Build and Install ZeroClaw
#
# Uses env var overrides for all external commands.
# The cargo install mock writes a marker file to confirm it was called.

load '../test_helper'

ZEROCLAW_SCRIPT="${SCRIPTS_DIR}/install/zeroclaw.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    export OLDINTELCLAW_INSTALL_MARKER="${TEST_TMPDIR}/cargo_install_called"

    # Default: zeroclaw already installed
    export OLDINTELCLAW_CMD_ZEROCLAW_CHECK="echo zeroclaw 0.1.0"

    # Default: cargo install does nothing (shouldn't be reached when already installed)
    export OLDINTELCLAW_CMD_CARGO_INSTALL="true"

    # Default: post-install check succeeds
    export OLDINTELCLAW_CMD_ZEROCLAW_POST="echo zeroclaw 0.1.0"

    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_INSTALL_MARKER
    unset OLDINTELCLAW_CMD_ZEROCLAW_CHECK
    unset OLDINTELCLAW_CMD_CARGO_INSTALL
    unset OLDINTELCLAW_CMD_ZEROCLAW_POST
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: ZeroClaw already installed — SKIP, exits 0
# ---------------------------------------------------------------------------
@test "ZeroClaw already installed: SKIP and exits 0" {
    run "${ZEROCLAW_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    # cargo install must NOT have been called
    [ ! -f "${OLDINTELCLAW_INSTALL_MARKER}" ]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh install succeeds — INSTALLED, exits 0
# ---------------------------------------------------------------------------
@test "Fresh install succeeds: INSTALLED and exits 0" {
    # ZeroClaw not present before install
    export OLDINTELCLAW_CMD_ZEROCLAW_CHECK="false"

    # cargo install succeeds and writes marker
    export OLDINTELCLAW_CMD_CARGO_INSTALL="touch ${OLDINTELCLAW_INSTALL_MARKER}"

    # post-install check succeeds
    export OLDINTELCLAW_CMD_ZEROCLAW_POST="echo zeroclaw 0.1.0"

    run "${ZEROCLAW_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALLED"* ]]
    # cargo install was called
    [ -f "${OLDINTELCLAW_INSTALL_MARKER}" ]
}

# ---------------------------------------------------------------------------
# Test 3: Install fails — FAIL, exits 1
# ---------------------------------------------------------------------------
@test "Install fails: FAIL status and exits 1" {
    export OLDINTELCLAW_CMD_ZEROCLAW_CHECK="false"
    export OLDINTELCLAW_CMD_CARGO_INSTALL="false"
    export OLDINTELCLAW_CMD_ZEROCLAW_POST="false"

    run "${ZEROCLAW_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Creates ~/.oldintelclaw/ directory if not exists
# ---------------------------------------------------------------------------
@test "Creates OLDINTELCLAW_HOME directory when it does not exist" {
    export OLDINTELCLAW_CMD_ZEROCLAW_CHECK="false"
    export OLDINTELCLAW_CMD_CARGO_INSTALL="touch ${OLDINTELCLAW_INSTALL_MARKER}"
    export OLDINTELCLAW_CMD_ZEROCLAW_POST="echo zeroclaw 0.1.0"

    # Confirm directory does not exist before run
    [ ! -d "${OLDINTELCLAW_HOME}" ]

    run "${ZEROCLAW_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -d "${OLDINTELCLAW_HOME}" ]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run — prints plan, no cargo install called
# ---------------------------------------------------------------------------
@test "Dry run mode: prints plan and does not call cargo install" {
    export OLDINTELCLAW_CMD_ZEROCLAW_CHECK="false"
    export OLDINTELCLAW_CMD_CARGO_INSTALL="touch ${OLDINTELCLAW_INSTALL_MARKER}"
    export OLDINTELCLAW_DRY_RUN="1"

    run "${ZEROCLAW_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"dry"* ]] || [[ "$output" == *"DRY"* ]] || [[ "$output" == *"plan"* ]] || [[ "$output" == *"PLAN"* ]]
    # cargo install must NOT have been called
    [ ! -f "${OLDINTELCLAW_INSTALL_MARKER}" ]
}
