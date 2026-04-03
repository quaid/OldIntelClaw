#!/usr/bin/env bats
# Unit tests for scripts/verify/dependencies.sh — Story 2.6: Dependency Verification Suite
#
# Uses env var overrides for every external command so tests never need real
# tool installations, GPU hardware, or group membership.
#
# Overridable env vars:
#   OLDINTELCLAW_CMD_OPENVINO        — check openvino import (exit 0 = ok)
#   OLDINTELCLAW_CMD_OPENVINO_GPU    — check GPU device available (exit 0 = ok)
#   OLDINTELCLAW_CMD_RUST            — check rustc (exit 0 = ok)
#   OLDINTELCLAW_CMD_CARGO           — check cargo (exit 0 = ok)
#   OLDINTELCLAW_CMD_PYTHON_VERSION  — stdout parsed for "Python X.Y.Z"
#   OLDINTELCLAW_CMD_ITREX           — check ITREX import (exit 0 = ok)
#   OLDINTELCLAW_CMD_ID_GROUPS       — stdout is space-separated group list
#   OLDINTELCLAW_CMD_RPM_QUERY       — check rpm packages (exit 0 = installed)
#   OLDINTELCLAW_DRI_RENDER          — path to render device (file must exist)
#   OLDINTELCLAW_VERIFY_LOG          — log file output path

load '../test_helper'

VERIFY_SCRIPT="${SCRIPTS_DIR}/verify/dependencies.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_VERIFY_LOG="${TEST_TMPDIR}/verify.log"

    # Create a fake render device file so the path-existence check passes
    FAKE_DRI_RENDER="${TEST_TMPDIR}/renderD128"
    touch "${FAKE_DRI_RENDER}"
    export OLDINTELCLAW_DRI_RENDER="${FAKE_DRI_RENDER}"

    # Default: all checks pass
    export OLDINTELCLAW_CMD_OPENVINO="true"
    export OLDINTELCLAW_CMD_OPENVINO_GPU="true"
    export OLDINTELCLAW_CMD_RUST="true"
    export OLDINTELCLAW_CMD_CARGO="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.12.4"
    export OLDINTELCLAW_CMD_ITREX="true"
    export OLDINTELCLAW_CMD_ID_GROUPS="echo video render wheel"
    export OLDINTELCLAW_CMD_RPM_QUERY="true"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_VERIFY_LOG
    unset OLDINTELCLAW_DRI_RENDER
    unset OLDINTELCLAW_CMD_OPENVINO
    unset OLDINTELCLAW_CMD_OPENVINO_GPU
    unset OLDINTELCLAW_CMD_RUST
    unset OLDINTELCLAW_CMD_CARGO
    unset OLDINTELCLAW_CMD_PYTHON_VERSION
    unset OLDINTELCLAW_CMD_ITREX
    unset OLDINTELCLAW_CMD_ID_GROUPS
    unset OLDINTELCLAW_CMD_RPM_QUERY
}

# ---------------------------------------------------------------------------
# Test 1: All checks pass — all OK, overall PASS, exits 0
# ---------------------------------------------------------------------------
@test "All checks pass: all OK, overall PASS, exits 0" {
    run "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]

    # Every major component must appear
    [[ "$output" == *"OpenVINO"* ]]
    [[ "$output" == *"Rust"* ]]
    [[ "$output" == *"Python"* ]]
    [[ "$output" == *"ITREX"* ]]

    # At least one OK result
    [[ "$output" == *"OK"* ]]

    # No FAIL results
    [[ "$output" != *"FAIL"* ]]

    # Overall summary must say PASS
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: All checks fail — all FAIL, overall FAIL, exits 1
# ---------------------------------------------------------------------------
@test "All checks fail: all FAIL, overall FAIL, exits 1" {
    export OLDINTELCLAW_CMD_OPENVINO="false"
    export OLDINTELCLAW_CMD_OPENVINO_GPU="false"
    export OLDINTELCLAW_CMD_RUST="false"
    export OLDINTELCLAW_CMD_CARGO="false"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="false"
    export OLDINTELCLAW_CMD_ITREX="false"
    export OLDINTELCLAW_CMD_ID_GROUPS="echo wheel"
    export OLDINTELCLAW_CMD_RPM_QUERY="false"
    # Remove the render device so that check also fails
    rm -f "${FAKE_DRI_RENDER}"
    export OLDINTELCLAW_DRI_RENDER="${TEST_TMPDIR}/renderD128_missing"

    run "${VERIFY_SCRIPT}"

    [ "$status" -eq 1 ]

    # At least one FAIL result
    [[ "$output" == *"FAIL"* ]]

    # Overall summary must say FAIL (not PASS)
    # The overall line should contain FAIL and not a standalone PASS
    overall_line="$(echo "$output" | grep -iE "overall|PASS|FAIL" | tail -1)"
    [[ "$overall_line" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Mixed results — correct per-component status, exits 1
# ---------------------------------------------------------------------------
@test "Mixed results: Rust OK, OpenVINO FAIL, overall FAIL, exits 1" {
    export OLDINTELCLAW_CMD_OPENVINO="false"
    export OLDINTELCLAW_CMD_OPENVINO_GPU="false"
    export OLDINTELCLAW_CMD_RUST="true"
    export OLDINTELCLAW_CMD_CARGO="true"
    # Python, ITREX, groups, render device, rpm remain passing from setup

    run "${VERIFY_SCRIPT}"

    [ "$status" -eq 1 ]

    # Rust-related lines must show OK
    rust_line="$(echo "$output" | grep -i "rustc\|Rust")"
    [[ "$rust_line" == *"OK"* ]]

    # OpenVINO import line must show FAIL
    openvino_line="$(echo "$output" | grep -i "OpenVINO" | head -1)"
    [[ "$openvino_line" == *"FAIL"* ]]

    # Overall must be FAIL because at least one check failed
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Log file is written to OLDINTELCLAW_VERIFY_LOG
# ---------------------------------------------------------------------------
@test "Log file is written to OLDINTELCLAW_VERIFY_LOG path" {
    run "${VERIFY_SCRIPT}"

    # Log file must exist
    [ -f "${OLDINTELCLAW_VERIFY_LOG}" ]

    # Log must contain component output (at minimum something about the result)
    log_content="$(cat "${OLDINTELCLAW_VERIFY_LOG}")"
    [[ "$log_content" == *"OK"* ]] || [[ "$log_content" == *"PASS"* ]] || [[ "$log_content" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Output includes component count (e.g. "7/7 checks passed")
# ---------------------------------------------------------------------------
@test "Output includes component count in N/N format when all pass" {
    run "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]

    # Must contain a count pattern like "7/7" or similar N/N
    [[ "$output" =~ [0-9]+/[0-9]+" checks" ]] || [[ "$output" =~ [0-9]+/[0-9]+" passed" ]] || [[ "$output" =~ [0-9]+/[0-9]+" check" ]]
}

# ---------------------------------------------------------------------------
# Test 6: Group membership — user in video+render → both OK
# ---------------------------------------------------------------------------
@test "Group membership: user in video and render shows OK for both" {
    export OLDINTELCLAW_CMD_ID_GROUPS="echo video render wheel"

    run "${VERIFY_SCRIPT}"

    [ "$status" -eq 0 ]

    # Both group lines must appear and show OK
    video_line="$(echo "$output" | grep -i "video")"
    [[ "$video_line" == *"OK"* ]]

    render_line="$(echo "$output" | grep -i "render" | grep -iv "renderD\|/dev")"
    [[ "$render_line" == *"OK"* ]]
}
