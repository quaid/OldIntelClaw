#!/usr/bin/env bats
# Unit tests for scripts/lib/state.sh
# Story 6.2: Structured Error Handling and Rollback

load '../test_helper'

STATE_LIB="${SCRIPTS_DIR}/lib/state.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/.oldintelclaw"
    export OLDINTELCLAW_STATE_FILE="${OLDINTELCLAW_HOME}/.setup-state.json"
    mkdir -p "${OLDINTELCLAW_HOME}"

    # Source the state library into the test shell for direct function testing.
    # We use a subshell per-test via `run`, but for direct calls we source here.
    # shellcheck source=/dev/null
    source "${STATE_LIB}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# init_state
# ---------------------------------------------------------------------------

@test "init_state creates state file when none exists" {
    [ ! -f "${OLDINTELCLAW_STATE_FILE}" ]
    init_state
    [ -f "${OLDINTELCLAW_STATE_FILE}" ]
}

@test "init_state creates valid JSON state file" {
    init_state
    # File must be non-empty and contain the version key
    local content
    content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
    [[ "$content" == *'"version"'* ]]
    [[ "$content" == *'"steps"'* ]]
}

@test "init_state loads existing state file without overwriting" {
    # Pre-create a state file with a known step
    cat > "${OLDINTELCLAW_STATE_FILE}" <<'JSON'
{"version":1,"last_run":"2026-01-01T00:00:00Z","steps":{"cpu_audit":"complete"}}
JSON

    init_state

    # The existing step must still be present
    local content
    content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
    [[ "$content" == *"cpu_audit"* ]]
    [[ "$content" == *"complete"* ]]
}

# ---------------------------------------------------------------------------
# mark_step
# ---------------------------------------------------------------------------

@test "mark_step sets a step to complete" {
    init_state
    mark_step "cpu_audit" "complete"

    local content
    content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
    [[ "$content" == *"cpu_audit"* ]]
    [[ "$content" == *"complete"* ]]
}

@test "mark_step sets a step to failed" {
    init_state
    mark_step "intel_packages" "failed"

    local content
    content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
    [[ "$content" == *"intel_packages"* ]]
    [[ "$content" == *"failed"* ]]
}

@test "mark_step overwrites a previous status for the same step" {
    init_state
    mark_step "os_audit" "failed"
    mark_step "os_audit" "complete"

    # get_step_status must now return complete, not failed
    local result
    result="$(get_step_status "os_audit")"
    [ "$result" = "complete" ]
}

# ---------------------------------------------------------------------------
# get_step_status
# ---------------------------------------------------------------------------

@test "get_step_status returns correct status for a known complete step" {
    init_state
    mark_step "cpu_audit" "complete"

    local result
    result="$(get_step_status "cpu_audit")"
    [ "$result" = "complete" ]
}

@test "get_step_status returns correct status for a known failed step" {
    init_state
    mark_step "intel_packages" "failed"

    local result
    result="$(get_step_status "intel_packages")"
    [ "$result" = "failed" ]
}

@test "get_step_status returns pending for an unknown step" {
    init_state

    local result
    result="$(get_step_status "nonexistent_step")"
    [ "$result" = "pending" ]
}

# ---------------------------------------------------------------------------
# should_skip
# ---------------------------------------------------------------------------

@test "should_skip returns 0 (true) for a complete step" {
    init_state
    mark_step "cpu_audit" "complete"

    should_skip "cpu_audit"
    [ "$?" -eq 0 ]
}

@test "should_skip returns 1 (false) for a pending step" {
    init_state

    should_skip "cpu_audit"
    [ "$?" -eq 1 ]
}

@test "should_skip returns 1 (false) for a failed step" {
    init_state
    mark_step "cpu_audit" "failed"

    should_skip "cpu_audit"
    [ "$?" -eq 1 ]
}

@test "should_skip returns 1 (false) for a step that has never been recorded" {
    init_state

    should_skip "never_recorded_step"
    [ "$?" -eq 1 ]
}

# ---------------------------------------------------------------------------
# reset_state
# ---------------------------------------------------------------------------

@test "reset_state clears the state file back to empty steps" {
    init_state
    mark_step "cpu_audit" "complete"
    mark_step "os_audit" "complete"

    reset_state

    # After reset, no steps should remain from before
    local content
    content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
    [[ "$content" != *"cpu_audit"* ]]
    [[ "$content" != *"os_audit"* ]]
}

@test "reset_state leaves a valid (empty steps) state file in place" {
    init_state
    mark_step "cpu_audit" "complete"

    reset_state

    [ -f "${OLDINTELCLAW_STATE_FILE}" ]
    local content
    content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
    [[ "$content" == *'"steps"'* ]]
    [[ "$content" == *'"version"'* ]]
}

# ---------------------------------------------------------------------------
# Integration: --reset flag in setup.sh calls reset_state (Story 6.1 x 6.2)
# ---------------------------------------------------------------------------

@test "--reset flag in setup.sh clears existing state" {
    # Write a state file with completed steps
    cat > "${OLDINTELCLAW_STATE_FILE}" <<'JSON'
{"version":1,"last_run":"2026-01-01T00:00:00Z","steps":{"cpu_audit":"complete","os_audit":"complete"}}
JSON

    # Run setup.sh --reset (with mocked sub-scripts)
    export OLDINTELCLAW_AUDIT_CMD="true"
    export OLDINTELCLAW_INSTALL_CMD="true"
    export OLDINTELCLAW_VERIFY_CMD="true"

    run "${SCRIPTS_DIR}/setup.sh" --reset
    [ "$status" -eq 0 ]

    # The state file must no longer contain the old completed steps
    if [ -f "${OLDINTELCLAW_STATE_FILE}" ]; then
        local content
        content="$(cat "${OLDINTELCLAW_STATE_FILE}")"
        [[ "$content" != *'"cpu_audit"'* ]] || [[ "$content" != *'"complete"'* ]]
    fi
}
