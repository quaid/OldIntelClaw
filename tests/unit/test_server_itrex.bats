#!/usr/bin/env bats
# Unit tests for scripts/server/itrex_server.sh — Story 5.3: ITREX Inference Endpoint
#
# Uses env var overrides so tests never start a real server.
#   OLDINTELCLAW_HOME              — temp dir acting as home
#   OLDINTELCLAW_CMD_ITREX_START   — override server start command
#   OLDINTELCLAW_CMD_ITREX_HEALTH  — override health check command
#   OLDINTELCLAW_ITREX_PORT        — override port (default 8002)
#   OLDINTELCLAW_DRY_RUN           — if "1", print launch plan and exit 0

load '../test_helper'

ITREX_SCRIPT="${SCRIPTS_DIR}/server/itrex_server.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}/models/itrex"

    # Place a dummy ITREX model so the server has something to load
    touch "${OLDINTELCLAW_HOME}/models/itrex/test_model"

    # Default: server start does nothing (succeeds silently)
    export OLDINTELCLAW_CMD_ITREX_START="true"

    # Default: health check passes
    export OLDINTELCLAW_CMD_ITREX_HEALTH="true"

    # Default: port
    export OLDINTELCLAW_ITREX_PORT="8002"

    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CMD_ITREX_START
    unset OLDINTELCLAW_CMD_ITREX_HEALTH
    unset OLDINTELCLAW_ITREX_PORT
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: Dry run — prints plan with model paths and port, exits 0
# ---------------------------------------------------------------------------
@test "ITREX: dry run prints launch plan with model paths and port, exits 0" {
    export OLDINTELCLAW_DRY_RUN="1"
    export OLDINTELCLAW_CMD_ITREX_START="false"

    run "${ITREX_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY"* ]] || [[ "$output" == *"dry"* ]]
    [[ "$output" == *"itrex"* ]] || [[ "$output" == *"model"* ]] || [[ "$output" == *"ITREX"* ]]
    [[ "$output" == *"8002"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Server starts and health check passes — PASS, exits 0
# ---------------------------------------------------------------------------
@test "ITREX: server starts and health check passes — PASS and exits 0" {
    export OLDINTELCLAW_CMD_ITREX_START="true"
    export OLDINTELCLAW_CMD_ITREX_HEALTH="true"

    run "${ITREX_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Server starts but health check fails — FAIL, exits 1
# ---------------------------------------------------------------------------
@test "ITREX: health check fails — FAIL and exits 1" {
    export OLDINTELCLAW_CMD_ITREX_START="true"
    export OLDINTELCLAW_CMD_ITREX_HEALTH="false"

    run "${ITREX_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: No ITREX models found — FAIL with message, exits 1
# ---------------------------------------------------------------------------
@test "ITREX: no models found in itrex directory — FAIL with message and exits 1" {
    # Remove all model files so the directory is empty
    rm -f "${OLDINTELCLAW_HOME}/models/itrex/"*

    run "${ITREX_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"itrex"* ]] || [[ "$output" == *"model"* ]] || [[ "$output" == *"ITREX"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Uses correct port (8002)
# ---------------------------------------------------------------------------
@test "ITREX: output includes the configured port 8002" {
    export OLDINTELCLAW_ITREX_PORT="8002"

    run "${ITREX_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"8002"* ]]
}
