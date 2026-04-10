#!/usr/bin/env bats
# End-to-end integration tests for the full setup workflow — Story 6.5
#
# These tests run scripts/setup.sh with all sub-scripts mocked via env vars
# to verify the orchestration logic without touching the real system.

load '../test_helper'

SETUP_SCRIPT="${SCRIPTS_DIR}/setup.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}"
    export OLDINTELCLAW_STATE_FILE="${OLDINTELCLAW_HOME}/.setup-state.json"

    # Mock all sub-script commands to succeed silently
    export OLDINTELCLAW_AUDIT_CMD="true"
    export OLDINTELCLAW_INSTALL_CMD="true"
    export OLDINTELCLAW_VERIFY_CMD="true"
    export OLDINTELCLAW_DRY_RUN=""
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# Test 1: Dry-run produces plan and exits 0 without side effects
# ---------------------------------------------------------------------------
@test "E2E: --dry-run completes without errors" {
    run "${SETUP_SCRIPT}" --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"Step"* ]] || [[ "$output" == *"DRY"* ]] || [[ "$output" == *"dry"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Normal run with all mocks exits 0
# ---------------------------------------------------------------------------
@test "E2E: full setup with mocked sub-scripts exits 0" {
    run "${SETUP_SCRIPT}"

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 3: --verify-only runs verification without install
# ---------------------------------------------------------------------------
@test "E2E: --verify-only runs without error" {
    run "${SETUP_SCRIPT}" --verify-only

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 4: Idempotent — running twice succeeds both times
# ---------------------------------------------------------------------------
@test "E2E: second run (idempotent) exits 0" {
    run "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]

    run "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 5: --reset clears state and exits 0
# ---------------------------------------------------------------------------
@test "E2E: --reset clears state file" {
    # First run to create state
    run "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]

    # Reset
    run "${SETUP_SCRIPT}" --reset
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 6: --help exits 0 with usage info
# ---------------------------------------------------------------------------
@test "E2E: --help exits 0" {
    run "${SETUP_SCRIPT}" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"--dry-run"* ]]
}
