#!/usr/bin/env bats
# Unit tests for scripts/lib/logging.sh
# Story 6.3: Logging and Diagnostics Output

load '../test_helper'

LOGGING_LIB="${SCRIPTS_DIR}/lib/logging.sh"

# ---------------------------------------------------------------------------
# Setup/teardown: use a temp dir for log files so tests are isolated
# ---------------------------------------------------------------------------

setup() {
    TEST_LOG_DIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_LOG_DIR}"
    export OLDINTELCLAW_LOG_FILE="${TEST_LOG_DIR}/setup.log"
    export OLDINTELCLAW_VERBOSE=""
    export OLDINTELCLAW_LOG_MAX_FILES=5
    # Source the library in the test environment
    # shellcheck source=/dev/null
    source "${LOGGING_LIB}"
}

teardown() {
    rm -rf "${TEST_LOG_DIR}"
}

# ---------------------------------------------------------------------------
# Test 1: log_init creates the log file
# ---------------------------------------------------------------------------

@test "log_init creates log file when it does not exist" {
    [ ! -f "${OLDINTELCLAW_LOG_FILE}" ]
    log_init
    [ -f "${OLDINTELCLAW_LOG_FILE}" ]
}

# ---------------------------------------------------------------------------
# Test 2: log_init rotates existing log (setup.log -> setup.log.1)
# ---------------------------------------------------------------------------

@test "log_init rotates existing log to setup.log.1" {
    echo "old log content" > "${OLDINTELCLAW_LOG_FILE}"
    log_init
    [ -f "${OLDINTELCLAW_LOG_FILE}.1" ]
    grep -q "old log content" "${OLDINTELCLAW_LOG_FILE}.1"
}

# ---------------------------------------------------------------------------
# Test 3: log_msg INFO writes timestamped line to log file
# ---------------------------------------------------------------------------

@test "log_msg INFO writes timestamped line to log file" {
    log_init
    log_msg INFO "hello from test"
    grep -q "INFO" "${OLDINTELCLAW_LOG_FILE}"
    grep -q "hello from test" "${OLDINTELCLAW_LOG_FILE}"
}

# ---------------------------------------------------------------------------
# Test 4: log_msg DEBUG does NOT write when VERBOSE is not set
# ---------------------------------------------------------------------------

@test "log_msg DEBUG does not write to log when OLDINTELCLAW_VERBOSE is unset" {
    export OLDINTELCLAW_VERBOSE=""
    log_init
    log_msg DEBUG "secret debug message"
    run grep "secret debug message" "${OLDINTELCLAW_LOG_FILE}"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Test 5: log_msg DEBUG DOES write when OLDINTELCLAW_VERBOSE=1
# ---------------------------------------------------------------------------

@test "log_msg DEBUG writes to log when OLDINTELCLAW_VERBOSE=1" {
    export OLDINTELCLAW_VERBOSE="1"
    log_init
    log_msg DEBUG "verbose debug message"
    grep -q "verbose debug message" "${OLDINTELCLAW_LOG_FILE}"
}

# ---------------------------------------------------------------------------
# Test 6: log_rotate keeps only N most recent log files
# ---------------------------------------------------------------------------

@test "log_rotate keeps only LOG_MAX_FILES log files (max=2, create 4)" {
    export OLDINTELCLAW_LOG_MAX_FILES=2
    # Create 4 existing rotated logs
    echo "log3" > "${OLDINTELCLAW_LOG_FILE}.3"
    echo "log2" > "${OLDINTELCLAW_LOG_FILE}.2"
    echo "log1" > "${OLDINTELCLAW_LOG_FILE}.1"
    echo "current" > "${OLDINTELCLAW_LOG_FILE}"
    log_rotate
    # After rotation, .1 and .2 should exist (from current and old .1)
    # .3 and .4 should not exist beyond max files
    local count
    count=$(ls "${TEST_LOG_DIR}"/setup.log.* 2>/dev/null | wc -l)
    [ "$count" -le 2 ]
}

# ---------------------------------------------------------------------------
# Test 7: log_init writes header with hostname
# ---------------------------------------------------------------------------

@test "log_init writes header containing hostname" {
    log_init
    grep -q "$(hostname)" "${OLDINTELCLAW_LOG_FILE}"
}
