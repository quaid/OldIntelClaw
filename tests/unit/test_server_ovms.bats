#!/usr/bin/env bats
# Unit tests for scripts/server/ovms.sh — Story 5.1: OpenVINO Model Server Launch
#
# Uses env var overrides so tests never start a real server.
#   OLDINTELCLAW_HOME            — temp dir acting as home
#   OLDINTELCLAW_CMD_OVMS_START  — override server start command
#   OLDINTELCLAW_CMD_OVMS_HEALTH — override health check command
#   OLDINTELCLAW_OVMS_PORT       — override port (default 8000)
#   OLDINTELCLAW_DRY_RUN         — if "1", print config and exit 0

load '../test_helper'

OVMS_SCRIPT="${SCRIPTS_DIR}/server/ovms.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}/models/openvino"

    # Place a dummy model so the config has something to reference
    touch "${OLDINTELCLAW_HOME}/models/openvino/test_model"

    # Default: server start does nothing (succeeds silently)
    export OLDINTELCLAW_CMD_OVMS_START="true"

    # Default: health check passes
    export OLDINTELCLAW_CMD_OVMS_HEALTH="true"

    # Default: port
    export OLDINTELCLAW_OVMS_PORT="8000"

    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CMD_OVMS_START
    unset OLDINTELCLAW_CMD_OVMS_HEALTH
    unset OLDINTELCLAW_OVMS_PORT
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: Generates ovms_config.json with correct model paths
# ---------------------------------------------------------------------------
@test "OVMS: generates ovms_config.json with model path entries" {
    run "${OVMS_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${OLDINTELCLAW_HOME}/ovms_config.json" ]

    config_content="$(cat "${OLDINTELCLAW_HOME}/ovms_config.json")"
    [[ "$config_content" == *"openvino"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Dry run — prints config, no server started, exits 0
# ---------------------------------------------------------------------------
@test "OVMS: dry run prints config and exits 0 without starting server" {
    export OLDINTELCLAW_DRY_RUN="1"
    # If start were called it would still succeed, but we verify output says DRY RUN
    export OLDINTELCLAW_CMD_OVMS_START="false"

    run "${OVMS_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY"* ]] || [[ "$output" == *"dry"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Server starts and health check passes — PASS, exits 0
# ---------------------------------------------------------------------------
@test "OVMS: server starts and health check passes — PASS and exits 0" {
    export OLDINTELCLAW_CMD_OVMS_START="true"
    export OLDINTELCLAW_CMD_OVMS_HEALTH="true"

    run "${OVMS_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Server starts but health check fails — FAIL, exits 1
# ---------------------------------------------------------------------------
@test "OVMS: health check fails — FAIL and exits 1" {
    export OLDINTELCLAW_CMD_OVMS_START="true"
    export OLDINTELCLAW_CMD_OVMS_HEALTH="false"

    run "${OVMS_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Config includes correct port number
# ---------------------------------------------------------------------------
@test "OVMS: config and output include the configured port number" {
    export OLDINTELCLAW_OVMS_PORT="8000"

    run "${OVMS_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"8000"* ]]
}
