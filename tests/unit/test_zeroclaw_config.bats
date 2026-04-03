#!/usr/bin/env bats
# Unit tests for scripts/config/zeroclaw_config.sh — Story 3.2: Generate Default config.toml
#
# Uses env var overrides so tests never touch the real filesystem.
# setup/teardown use a temp dir for OLDINTELCLAW_HOME.

load '../test_helper'

ZEROCLAW_CONFIG_SCRIPT="${SCRIPTS_DIR}/config/zeroclaw_config.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}"
    export OLDINTELCLAW_CONFIG_FILE="${OLDINTELCLAW_HOME}/config.toml"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CONFIG_FILE
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: No existing config — creates config.toml, exits 0
# ---------------------------------------------------------------------------
@test "No existing config: creates config.toml and exits 0" {
    [ ! -f "${OLDINTELCLAW_CONFIG_FILE}" ]

    run "${ZEROCLAW_CONFIG_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${OLDINTELCLAW_CONFIG_FILE}" ]
}

# ---------------------------------------------------------------------------
# Test 2: Config content is valid TOML with all 5 models
# ---------------------------------------------------------------------------
@test "Config contains all 5 model sections" {
    run "${ZEROCLAW_CONFIG_SCRIPT}"

    [ "$status" -eq 0 ]
    run grep -c '^\[models\.' "${OLDINTELCLAW_CONFIG_FILE}"
    [ "$output" -eq 5 ]
}

# ---------------------------------------------------------------------------
# Test 3: Config contains correct provider settings
# ---------------------------------------------------------------------------
@test "Config contains correct provider settings: llamacpp and localhost:8000" {
    run "${ZEROCLAW_CONFIG_SCRIPT}"

    [ "$status" -eq 0 ]

    run grep 'type = "llamacpp"' "${OLDINTELCLAW_CONFIG_FILE}"
    [ "$status" -eq 0 ]

    run grep 'base_url = "http://localhost:8000/v1"' "${OLDINTELCLAW_CONFIG_FILE}"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 4: Existing config — backs up to .bak file before writing
# ---------------------------------------------------------------------------
@test "Existing config is backed up to .bak file" {
    # Create an existing config
    echo "old content" > "${OLDINTELCLAW_CONFIG_FILE}"

    run "${ZEROCLAW_CONFIG_SCRIPT}"

    [ "$status" -eq 0 ]
    # A backup file matching the pattern must exist
    local backup_count
    backup_count="$(ls "${OLDINTELCLAW_HOME}/config.toml.bak."* 2>/dev/null | wc -l)"
    [ "${backup_count}" -ge 1 ]
}

# ---------------------------------------------------------------------------
# Test 5: Backup preserves original content
# ---------------------------------------------------------------------------
@test "Backup file preserves original config content" {
    local original_content="original config content for backup test"
    echo "${original_content}" > "${OLDINTELCLAW_CONFIG_FILE}"

    run "${ZEROCLAW_CONFIG_SCRIPT}"

    [ "$status" -eq 0 ]
    local backup_file
    backup_file="$(ls "${OLDINTELCLAW_HOME}/config.toml.bak."* 2>/dev/null | head -1)"
    [ -n "${backup_file}" ]
    run grep "${original_content}" "${backup_file}"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 6: Dry run — prints config to stdout, no file written
# ---------------------------------------------------------------------------
@test "Dry run: prints config to stdout and does not write file" {
    export OLDINTELCLAW_DRY_RUN="1"

    run "${ZEROCLAW_CONFIG_SCRIPT}"

    [ "$status" -eq 0 ]
    # Output must contain config content
    [[ "$output" == *"llamacpp"* ]]
    [[ "$output" == *"localhost:8000"* ]]
    # File must NOT have been written
    [ ! -f "${OLDINTELCLAW_CONFIG_FILE}" ]
}
