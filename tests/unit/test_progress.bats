#!/usr/bin/env bats
# Unit tests for scripts/lib/progress.sh
# Story 6.4: Progress Reporting for Long Operations

load '../test_helper'

PROGRESS_LIB="${SCRIPTS_DIR}/lib/progress.sh"

# ---------------------------------------------------------------------------
# Setup/teardown
# ---------------------------------------------------------------------------

setup() {
    export OLDINTELCLAW_PROGRESS_ENABLED="1"
    # Source the library in the test environment
    # shellcheck source=/dev/null
    source "${PROGRESS_LIB}"
}

teardown() {
    # Ensure any lingering spinner is killed
    spinner_stop 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Test 1: step_start outputs step number and description
# ---------------------------------------------------------------------------

@test "step_start 1 8 'System audit' outputs '[Step 1/8]' and 'System audit'" {
    run step_start 1 8 "System audit"
    [[ "$output" == *"[Step 1/8]"* ]]
    [[ "$output" == *"System audit"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: step_done outputs step marker and completion indicator
# ---------------------------------------------------------------------------

@test "step_done 1 8 'System audit' outputs '[Step 1/8]' and done indicator" {
    run step_done 1 8 "System audit"
    [[ "$output" == *"[Step 1/8]"* ]]
    # Accept either checkmark or the word "done"
    [[ "$output" == *"done"* ]] || [[ "$output" == *"✓"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: step_start works for various step numbers
# ---------------------------------------------------------------------------

@test "step_start 3 8 outputs '[Step 3/8]'" {
    run step_start 3 8 "Installing packages"
    [[ "$output" == *"[Step 3/8]"* ]]
    [[ "$output" == *"Installing packages"* ]]
}

@test "step_start 8 8 outputs '[Step 8/8]'" {
    run step_start 8 8 "Finalizing"
    [[ "$output" == *"[Step 8/8]"* ]]
    [[ "$output" == *"Finalizing"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: spinner_start launches a background process
# ---------------------------------------------------------------------------

@test "spinner_start sets a PID that refers to a running process" {
    spinner_start "Working..."
    # Give the spinner a moment to start
    sleep 0.1
    [ -n "${SPINNER_PID:-}" ]
    kill -0 "${SPINNER_PID}" 2>/dev/null
    spinner_stop
}

# ---------------------------------------------------------------------------
# Test 5: spinner_stop kills the background process
# ---------------------------------------------------------------------------

@test "spinner_stop kills the spinner background process" {
    spinner_start "Working..."
    sleep 0.1
    local pid="${SPINNER_PID}"
    spinner_stop
    sleep 0.1
    # Process should no longer be running
    run kill -0 "$pid"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Test 6: When PROGRESS_ENABLED=0, step functions still output text
# ---------------------------------------------------------------------------

@test "step_start outputs text even when OLDINTELCLAW_PROGRESS_ENABLED=0" {
    export OLDINTELCLAW_PROGRESS_ENABLED="0"
    run step_start 1 8 "System audit"
    [[ "$output" == *"[Step 1/8]"* ]]
    [[ "$output" == *"System audit"* ]]
}

@test "step_done outputs text even when OLDINTELCLAW_PROGRESS_ENABLED=0" {
    export OLDINTELCLAW_PROGRESS_ENABLED="0"
    run step_done 1 8 "System audit"
    [[ "$output" == *"[Step 1/8]"* ]]
    [[ "$output" == *"done"* ]] || [[ "$output" == *"✓"* ]]
}
