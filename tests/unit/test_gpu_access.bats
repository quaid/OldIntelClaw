#!/usr/bin/env bats
# Unit tests for scripts/install/gpu_access.sh — Story 2.3: Configure iGPU Access
#
# Uses env var overrides so tests never need real group membership or root.
# Usermod calls are mocked via OLDINTELCLAW_CMD_USERMOD writing a marker file.

load '../test_helper'

GPU_SCRIPT="${SCRIPTS_DIR}/install/gpu_access.sh"

setup() {
    # Fresh temp dir per test
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_USERMOD_MARKER="${TEST_TMPDIR}/usermod_calls"

    # Default mock: simulate root, user is "testuser"
    export OLDINTELCLAW_CMD_IS_ROOT="1"
    export OLDINTELCLAW_CMD_WHOAMI="echo testuser"

    # Default mock usermod: record the call instead of running real usermod
    export OLDINTELCLAW_CMD_USERMOD="bash -c 'echo usermod \"\$@\" >> ${TEST_TMPDIR}/usermod_calls' --"

    # Default: user in neither group (will be overridden per test)
    export OLDINTELCLAW_CMD_ID_GROUPS="echo"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# Test 1: User already in both groups — both SKIP, exits 0, no logout warning
# ---------------------------------------------------------------------------
@test "User already in both groups: both SKIP, exits 0, no logout warning" {
    export OLDINTELCLAW_CMD_ID_GROUPS="echo video render wheel"

    run "${GPU_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"video"* ]]
    [[ "$output" == *"render"* ]]
    [[ "$output" == *"SKIP"* ]]
    # No usermod should have been called
    [ ! -f "${OLDINTELCLAW_USERMOD_MARKER}" ]
    # No logout warning when nothing was changed
    [[ "$output" != *"logout"* ]] && [[ "$output" != *"log out"* ]] && [[ "$output" != *"re-login"* ]] || false
}

# ---------------------------------------------------------------------------
# Test 2: User in neither group — both ADDED, exits 0, logout warning printed
# ---------------------------------------------------------------------------
@test "User in neither group: both ADDED, exits 0, logout warning printed" {
    export OLDINTELCLAW_CMD_ID_GROUPS="echo wheel"

    run "${GPU_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"video"* ]]
    [[ "$output" == *"render"* ]]
    [[ "$output" == *"ADDED"* ]]
    # usermod must have been called
    [ -f "${OLDINTELCLAW_USERMOD_MARKER}" ]
    # Logout warning must appear
    [[ "$output" == *"logout"* ]] || [[ "$output" == *"log out"* ]] || [[ "$output" == *"re-login"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: User in video but not render — video SKIP, render ADDED, logout warning
# ---------------------------------------------------------------------------
@test "User in video but not render: video SKIP, render ADDED, logout warning" {
    export OLDINTELCLAW_CMD_ID_GROUPS="echo video wheel"

    run "${GPU_SCRIPT}"

    [ "$status" -eq 0 ]
    # video line must contain SKIP
    video_line="$(echo "$output" | grep -i "video")"
    [[ "$video_line" == *"SKIP"* ]]

    # render line must contain ADDED
    render_line="$(echo "$output" | grep -i "render")"
    [[ "$render_line" == *"ADDED"* ]]

    # Only one usermod call (for render)
    [ -f "${OLDINTELCLAW_USERMOD_MARKER}" ]
    usermod_count="$(wc -l < "${OLDINTELCLAW_USERMOD_MARKER}")"
    [ "$usermod_count" -eq 1 ]

    # Logout warning must appear
    [[ "$output" == *"logout"* ]] || [[ "$output" == *"log out"* ]] || [[ "$output" == *"re-login"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Not root — exits 1 with error message
# ---------------------------------------------------------------------------
@test "Not root: exits 1 with error message" {
    export OLDINTELCLAW_CMD_IS_ROOT="0"

    run "${GPU_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"root"* ]] || [[ "$output" == *"sudo"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run mode — prints plan, no usermod called
# ---------------------------------------------------------------------------
@test "Dry run mode: prints plan, no usermod called" {
    export OLDINTELCLAW_CMD_ID_GROUPS="echo wheel"
    export OLDINTELCLAW_DRY_RUN="1"

    run "${GPU_SCRIPT}"

    [ "$status" -eq 0 ]
    # Must mention both groups in output
    [[ "$output" == *"video"* ]]
    [[ "$output" == *"render"* ]]
    # Must indicate this is a dry run or plan
    [[ "$output" == *"dry"* ]] || [[ "$output" == *"DRY"* ]] || [[ "$output" == *"plan"* ]] || [[ "$output" == *"PLAN"* ]]
    # No actual usermod must have run
    [ ! -f "${OLDINTELCLAW_USERMOD_MARKER}" ]
}

# ---------------------------------------------------------------------------
# Additional: render already member, video missing — video ADDED, render SKIP
# ---------------------------------------------------------------------------
@test "User in render but not video: video ADDED, render SKIP, logout warning" {
    export OLDINTELCLAW_CMD_ID_GROUPS="echo render wheel"

    run "${GPU_SCRIPT}"

    [ "$status" -eq 0 ]

    video_line="$(echo "$output" | grep -i "video")"
    [[ "$video_line" == *"ADDED"* ]]

    render_line="$(echo "$output" | grep -i "render")"
    [[ "$render_line" == *"SKIP"* ]]

    [[ "$output" == *"logout"* ]] || [[ "$output" == *"log out"* ]] || [[ "$output" == *"re-login"* ]]
}
