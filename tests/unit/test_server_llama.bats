#!/usr/bin/env bats
# Unit tests for scripts/server/llama_server.sh — Story 5.2: llama-server with OpenVINO Backend
#
# Uses env var overrides so tests never start a real server.
#   OLDINTELCLAW_HOME             — temp dir acting as home
#   OLDINTELCLAW_CMD_LLAMA_START  — override server start command
#   OLDINTELCLAW_CMD_LLAMA_HEALTH — override health check command
#   OLDINTELCLAW_LLAMA_PORT       — override port (default 8001)
#   OLDINTELCLAW_DRY_RUN          — if "1", print launch plan and exit 0

load '../test_helper'

LLAMA_SCRIPT="${SCRIPTS_DIR}/server/llama_server.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}/models/gguf"

    # Place a dummy GGUF model file
    touch "${OLDINTELCLAW_HOME}/models/gguf/test_model.gguf"

    # Default: server start does nothing (succeeds silently)
    export OLDINTELCLAW_CMD_LLAMA_START="true"

    # Default: health check passes
    export OLDINTELCLAW_CMD_LLAMA_HEALTH="true"

    # Default: port
    export OLDINTELCLAW_LLAMA_PORT="8001"

    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CMD_LLAMA_START
    unset OLDINTELCLAW_CMD_LLAMA_HEALTH
    unset OLDINTELCLAW_LLAMA_PORT
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: Dry run — prints plan with model path and port, exits 0
# ---------------------------------------------------------------------------
@test "llama-server: dry run prints launch plan with model path and port, exits 0" {
    export OLDINTELCLAW_DRY_RUN="1"
    export OLDINTELCLAW_CMD_LLAMA_START="false"

    run "${LLAMA_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY"* ]] || [[ "$output" == *"dry"* ]]
    [[ "$output" == *"gguf"* ]] || [[ "$output" == *"model"* ]]
    [[ "$output" == *"8001"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Server starts and health check passes — PASS, exits 0
# ---------------------------------------------------------------------------
@test "llama-server: server starts and health check passes — PASS and exits 0" {
    export OLDINTELCLAW_CMD_LLAMA_START="true"
    export OLDINTELCLAW_CMD_LLAMA_HEALTH="true"

    run "${LLAMA_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Server starts but health check fails — FAIL, exits 1
# ---------------------------------------------------------------------------
@test "llama-server: health check fails — FAIL and exits 1" {
    export OLDINTELCLAW_CMD_LLAMA_START="true"
    export OLDINTELCLAW_CMD_LLAMA_HEALTH="false"

    run "${LLAMA_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: No GGUF model found — FAIL with message, exits 1
# ---------------------------------------------------------------------------
@test "llama-server: no GGUF model found — FAIL with message and exits 1" {
    # Remove all GGUF models from the directory
    rm -f "${OLDINTELCLAW_HOME}/models/gguf/"*.gguf

    run "${LLAMA_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"gguf"* ]] || [[ "$output" == *"model"* ]] || [[ "$output" == *"GGUF"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Uses correct port (8001)
# ---------------------------------------------------------------------------
@test "llama-server: output includes the configured port 8001" {
    export OLDINTELCLAW_LLAMA_PORT="8001"

    run "${LLAMA_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"8001"* ]]
}
