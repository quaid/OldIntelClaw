#!/usr/bin/env bats
# Unit tests for scripts/config/pairing.sh — Story 5.4: ZeroClaw Gateway Pairing
#
# Uses env var overrides so tests never contact real servers or write to real paths.
#   OLDINTELCLAW_HOME              — temp dir acting as home
#   OLDINTELCLAW_CONFIG_FILE       — temp config.toml path
#   OLDINTELCLAW_CMD_OVMS_PING     — override OVMS health check
#   OLDINTELCLAW_CMD_LLAMA_PING    — override llama-server health check
#   OLDINTELCLAW_CMD_ITREX_PING    — override ITREX health check
#   OLDINTELCLAW_CMD_ZEROCLAW_PING — override ZeroClaw round-trip test
#   OLDINTELCLAW_DRY_RUN           — if "1", print plan and exit 0

load '../test_helper'

PAIRING_SCRIPT="${SCRIPTS_DIR}/config/pairing.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}"
    export OLDINTELCLAW_CONFIG_FILE="${OLDINTELCLAW_HOME}/config.toml"

    # Default: all endpoints reachable
    export OLDINTELCLAW_CMD_OVMS_PING="true"
    export OLDINTELCLAW_CMD_LLAMA_PING="true"
    export OLDINTELCLAW_CMD_ITREX_PING="true"

    # Default: ZeroClaw round-trip succeeds
    export OLDINTELCLAW_CMD_ZEROCLAW_PING="true"

    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CONFIG_FILE
    unset OLDINTELCLAW_CMD_OVMS_PING
    unset OLDINTELCLAW_CMD_LLAMA_PING
    unset OLDINTELCLAW_CMD_ITREX_PING
    unset OLDINTELCLAW_CMD_ZEROCLAW_PING
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: All endpoints reachable — all PASS, exits 0
# ---------------------------------------------------------------------------
@test "Pairing: all endpoints reachable — all PASS and exits 0" {
    run "${PAIRING_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" != *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: OVMS unreachable — FAIL for OVMS, exits 1
# ---------------------------------------------------------------------------
@test "Pairing: OVMS unreachable — FAIL reported for OVMS and exits 1" {
    export OLDINTELCLAW_CMD_OVMS_PING="false"

    run "${PAIRING_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"ovms"* ]] || [[ "$output" == *"OVMS"* ]] || [[ "$output" == *"8000"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Config updated with all 3 endpoint URLs
# ---------------------------------------------------------------------------
@test "Pairing: config.toml updated with all 3 endpoint URLs" {
    run "${PAIRING_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${OLDINTELCLAW_CONFIG_FILE}" ]

    config_content="$(cat "${OLDINTELCLAW_CONFIG_FILE}")"
    [[ "$config_content" == *"8000"* ]]
    [[ "$config_content" == *"8001"* ]]
    [[ "$config_content" == *"8002"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Default routing configured (general→phi-4-mini)
# ---------------------------------------------------------------------------
@test "Pairing: default routing sets general→phi-4-mini in config" {
    run "${PAIRING_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${OLDINTELCLAW_CONFIG_FILE}" ]

    config_content="$(cat "${OLDINTELCLAW_CONFIG_FILE}")"
    [[ "$config_content" == *"phi-4-mini"* ]]
    [[ "$config_content" == *"general"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run — prints plan, no config changes, exits 0
# ---------------------------------------------------------------------------
@test "Pairing: dry run prints plan and does not write config, exits 0" {
    export OLDINTELCLAW_DRY_RUN="1"

    run "${PAIRING_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY"* ]] || [[ "$output" == *"dry"* ]]
    # Config file must not be written
    [ ! -f "${OLDINTELCLAW_CONFIG_FILE}" ]
}
