#!/usr/bin/env bats
# Unit tests for scripts/setup.sh
# Story 6.1: CLI Argument Parsing and Help System

load '../test_helper'

SETUP_SCRIPT="${SCRIPTS_DIR}/setup.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/.oldintelclaw"
    export OLDINTELCLAW_STATE_FILE="${OLDINTELCLAW_HOME}/.setup-state.json"

    # Prevent setup.sh from actually running sub-scripts during CLI tests.
    # Sub-script paths are overridden via env vars consumed by setup.sh.
    export OLDINTELCLAW_DRY_RUN=""
    export OLDINTELCLAW_SKIP_MODELS=""
    export OLDINTELCLAW_SKIP_KERNEL=""
    export OLDINTELCLAW_VERBOSE=""

    # Mock the sub-scripts so they don't execute real system operations.
    # setup.sh reads OLDINTELCLAW_AUDIT_CMD and OLDINTELCLAW_INSTALL_CMD for
    # overrideable entry points used during tests.
    export OLDINTELCLAW_AUDIT_CMD="true"
    export OLDINTELCLAW_INSTALL_CMD="true"
    export OLDINTELCLAW_VERIFY_CMD="true"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# --help / -h
# ---------------------------------------------------------------------------

@test "--help prints usage text and exits 0" {
    run "${SETUP_SCRIPT}" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "--help output contains all expected flag names" {
    run "${SETUP_SCRIPT}" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--skip-models"* ]]
    [[ "$output" == *"--skip-kernel"* ]]
    [[ "$output" == *"--verbose"* ]]
    [[ "$output" == *"--verify-only"* ]]
    [[ "$output" == *"--reset"* ]]
}

@test "-h prints usage text and exits 0" {
    run "${SETUP_SCRIPT}" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

# ---------------------------------------------------------------------------
# Unknown flags
# ---------------------------------------------------------------------------

@test "Unknown flag prints error and exits 1" {
    run "${SETUP_SCRIPT}" --unknown-flag-xyz
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"unknown"* ]] || [[ "$output" == *"invalid"* ]]
}

# ---------------------------------------------------------------------------
# --dry-run
# ---------------------------------------------------------------------------

@test "--dry-run sets DRY_RUN mode — output indicates dry run" {
    run "${SETUP_SCRIPT}" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry"* ]] || [[ "$output" == *"DRY"* ]] || [[ "$output" == *"dry-run"* ]]
}

# ---------------------------------------------------------------------------
# --verify-only
# ---------------------------------------------------------------------------

@test "--verify-only runs verification without installation steps" {
    run "${SETUP_SCRIPT}" --verify-only
    [ "$status" -eq 0 ]
    # Should mention verify/verification, not installation
    [[ "$output" == *"verif"* ]] || [[ "$output" == *"Verif"* ]]
}

# ---------------------------------------------------------------------------
# No arguments — normal flow with mocked sub-scripts
# ---------------------------------------------------------------------------

@test "No arguments starts normal setup flow and exits 0" {
    run "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# --skip-models
# ---------------------------------------------------------------------------

@test "--skip-models flag is recognized and does not error" {
    run "${SETUP_SCRIPT}" --skip-models
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# --skip-kernel
# ---------------------------------------------------------------------------

@test "--skip-kernel flag is recognized and does not error" {
    run "${SETUP_SCRIPT}" --skip-kernel
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# --verbose / -v
# ---------------------------------------------------------------------------

@test "--verbose flag is recognized and does not error" {
    run "${SETUP_SCRIPT}" --verbose
    [ "$status" -eq 0 ]
}

@test "-v flag is recognized and does not error" {
    run "${SETUP_SCRIPT}" -v
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# --reset
# ---------------------------------------------------------------------------

@test "--reset flag clears state file and exits 0" {
    # Pre-create a state file to verify it gets cleared
    mkdir -p "${OLDINTELCLAW_HOME}"
    echo '{"version":1,"steps":{"cpu_audit":"complete"}}' > "${OLDINTELCLAW_STATE_FILE}"

    run "${SETUP_SCRIPT}" --reset
    [ "$status" -eq 0 ]

    # State file should be gone or empty after reset
    if [ -f "${OLDINTELCLAW_STATE_FILE}" ]; then
        local content
        content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
        # If file exists it must have empty steps
        [[ "$content" != *"complete"* ]]
    fi
}

# ---------------------------------------------------------------------------
# Step progress headers
# ---------------------------------------------------------------------------

@test "Normal run prints Step N/8 progress headers" {
    run "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Step"* ]]
}
