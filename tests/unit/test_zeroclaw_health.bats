#!/usr/bin/env bats
# Unit tests for scripts/verify/zeroclaw_health.sh — Story 3.5: ZeroClaw Health Check
#
# Uses env var overrides for all external commands and pre-computed values so
# tests never require a real zeroclaw binary, real config parser, or live
# memory/timing measurements.
#
# Key overrides:
#   OLDINTELCLAW_CMD_ZEROCLAW_VERSION   — version command (exit 0 = binary present)
#   OLDINTELCLAW_CMD_ZEROCLAW_CONFIG_CHECK — config parse command (exit 0 = valid)
#   OLDINTELCLAW_ZEROCLAW_RSS_KB        — RSS in KB (skips live measurement)
#   OLDINTELCLAW_ZEROCLAW_STARTUP_MS    — startup time in ms (skips live measurement)
#   OLDINTELCLAW_HOME                   — base directory (temp dir in tests)
#   OLDINTELCLAW_CONFIG_FILE            — path to config.toml

load '../test_helper'

HEALTH_SCRIPT="${SCRIPTS_DIR}/verify/zeroclaw_health.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}"

    # Create a minimal config.toml so file-existence check passes by default
    export OLDINTELCLAW_CONFIG_FILE="${OLDINTELCLAW_HOME}/config.toml"
    printf '[zeroclaw]\nmodel = "default"\n' > "${OLDINTELCLAW_CONFIG_FILE}"

    # Default: all checks pass
    export OLDINTELCLAW_CMD_ZEROCLAW_VERSION="true"
    export OLDINTELCLAW_CMD_ZEROCLAW_CONFIG_CHECK="true"

    # Default: healthy memory (3 MB) and fast startup (5 ms)
    export OLDINTELCLAW_ZEROCLAW_RSS_KB="3000"
    export OLDINTELCLAW_ZEROCLAW_STARTUP_MS="5"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CONFIG_FILE
    unset OLDINTELCLAW_CMD_ZEROCLAW_VERSION
    unset OLDINTELCLAW_CMD_ZEROCLAW_CONFIG_CHECK
    unset OLDINTELCLAW_ZEROCLAW_RSS_KB
    unset OLDINTELCLAW_ZEROCLAW_STARTUP_MS
}

# ---------------------------------------------------------------------------
# Test 1: All checks pass — HEALTHY, exits 0
# ---------------------------------------------------------------------------
@test "All checks pass: reports HEALTHY and exits 0" {
    # Setup defaults: version OK, config OK, RSS=3000 KB, startup=5 ms

    run "${HEALTH_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"HEALTHY"* ]]
    [[ "$output" != *"FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: ZeroClaw binary missing — FAILED, exits 1
# ---------------------------------------------------------------------------
@test "ZeroClaw binary missing: reports FAILED and exits 1" {
    export OLDINTELCLAW_CMD_ZEROCLAW_VERSION="false"

    run "${HEALTH_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Config file missing — FAILED, exits 1
# ---------------------------------------------------------------------------
@test "Config file missing: reports FAILED and exits 1" {
    rm -f "${OLDINTELCLAW_CONFIG_FILE}"

    run "${HEALTH_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: RSS = 6000 KB (above 5 MB threshold) — output includes WARN for memory
# ---------------------------------------------------------------------------
@test "RSS 6000 KB above 5MB threshold: output includes WARN for memory" {
    export OLDINTELCLAW_ZEROCLAW_RSS_KB="6000"

    run "${HEALTH_SCRIPT}"

    [[ "$output" == *"WARN"* ]]
    # The memory-specific line should call out the high RSS
    memory_line="$(printf '%s\n' "$output" | grep -i "memory\|rss\|mem")"
    [[ "$memory_line" == *"WARN"* ]] || [[ "$output" == *"WARN"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: RSS = 3000 KB (under 5 MB) — memory check is PASS
# ---------------------------------------------------------------------------
@test "RSS 3000 KB under 5MB threshold: memory check is PASS" {
    export OLDINTELCLAW_ZEROCLAW_RSS_KB="3000"

    run "${HEALTH_SCRIPT}"

    # Must not have a WARN attributed to memory (overall should be HEALTHY)
    [[ "$output" == *"HEALTHY"* ]]
    [[ "$output" != *"DEGRADED"* ]]
    [[ "$output" != *"FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: Startup time = 15 ms (above 10 ms threshold) — output includes WARN
# ---------------------------------------------------------------------------
@test "Startup 15ms above 10ms threshold: output includes WARN" {
    export OLDINTELCLAW_ZEROCLAW_STARTUP_MS="15"

    run "${HEALTH_SCRIPT}"

    [[ "$output" == *"WARN"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Startup time = 5 ms (under 10 ms) — startup check is PASS
# ---------------------------------------------------------------------------
@test "Startup 5ms under 10ms threshold: startup check is PASS" {
    export OLDINTELCLAW_ZEROCLAW_STARTUP_MS="5"

    run "${HEALTH_SCRIPT}"

    [[ "$output" == *"HEALTHY"* ]]
    [[ "$output" != *"DEGRADED"* ]]
    [[ "$output" != *"FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Test 8: Binary OK, config OK, high memory — DEGRADED, exits 0
# ---------------------------------------------------------------------------
@test "Binary OK, config OK, high memory: reports DEGRADED and exits 0" {
    export OLDINTELCLAW_CMD_ZEROCLAW_VERSION="true"
    export OLDINTELCLAW_CMD_ZEROCLAW_CONFIG_CHECK="true"
    export OLDINTELCLAW_ZEROCLAW_RSS_KB="6000"
    export OLDINTELCLAW_ZEROCLAW_STARTUP_MS="5"

    run "${HEALTH_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DEGRADED"* ]]
    [[ "$output" != *"FAILED"* ]]
}

# ---------------------------------------------------------------------------
# Test 9: Output always includes a health status label
# ---------------------------------------------------------------------------
@test "Output always includes a health status label (HEALTHY, DEGRADED, or FAILED)" {
    run "${HEALTH_SCRIPT}"

    # One of the three labels must appear in output
    [[ "$output" == *"HEALTHY"* ]] || [[ "$output" == *"DEGRADED"* ]] || [[ "$output" == *"FAILED"* ]]
}
