#!/usr/bin/env bats
# Unit tests for scripts/models/store.sh — Story 4.1: Create Model Store Directory Structure
#
# Uses env var overrides so tests never touch the real filesystem.
# setup/teardown use a temp dir for OLDINTELCLAW_HOME.

load '../test_helper'

MODEL_STORE_SCRIPT="${SCRIPTS_DIR}/models/store.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: Fresh run — creates all directories, exits 0
# ---------------------------------------------------------------------------
@test "Fresh run: creates models/ and all backend subdirs, exits 0" {
    run "${MODEL_STORE_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -d "${OLDINTELCLAW_HOME}/models" ]
    [ -d "${OLDINTELCLAW_HOME}/models/openvino" ]
    [ -d "${OLDINTELCLAW_HOME}/models/itrex" ]
    [ -d "${OLDINTELCLAW_HOME}/models/gguf" ]
}

# ---------------------------------------------------------------------------
# Test 2: manifest.json created with correct content
# ---------------------------------------------------------------------------
@test "Creates manifest.json with valid JSON containing version and models keys" {
    run "${MODEL_STORE_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${OLDINTELCLAW_HOME}/models/manifest.json" ]

    # Must be valid JSON — python3 is a safe parser to use in bats
    run python3 -c "import json,sys; d=json.load(open('${OLDINTELCLAW_HOME}/models/manifest.json')); sys.exit(0 if 'version' in d and 'models' in d else 1)"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 3: Idempotent — re-run when directories exist exits 0 without error
# ---------------------------------------------------------------------------
@test "Idempotent: re-run when dirs already exist exits 0" {
    # First run to create everything
    run "${MODEL_STORE_SCRIPT}"
    [ "$status" -eq 0 ]

    # Second run must also succeed
    run "${MODEL_STORE_SCRIPT}"
    [ "$status" -eq 0 ]

    # Dirs still present
    [ -d "${OLDINTELCLAW_HOME}/models/openvino" ]
    [ -d "${OLDINTELCLAW_HOME}/models/itrex" ]
    [ -d "${OLDINTELCLAW_HOME}/models/gguf" ]
}

# ---------------------------------------------------------------------------
# Test 4: Does not overwrite an existing manifest.json
# ---------------------------------------------------------------------------
@test "Preserves existing manifest.json content on re-run" {
    # Create dirs so the script will skip directory creation
    mkdir -p "${OLDINTELCLAW_HOME}/models/openvino" \
             "${OLDINTELCLAW_HOME}/models/itrex" \
             "${OLDINTELCLAW_HOME}/models/gguf"

    # Write a custom manifest that should be preserved
    local custom_content='{"version":99,"models":{"my-model":{}}}'
    printf '%s\n' "${custom_content}" > "${OLDINTELCLAW_HOME}/models/manifest.json"

    run "${MODEL_STORE_SCRIPT}"

    [ "$status" -eq 0 ]

    # Content must not have changed — version 99 must still be there
    run python3 -c "import json,sys; d=json.load(open('${OLDINTELCLAW_HOME}/models/manifest.json')); sys.exit(0 if d['version']==99 else 1)"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 5: models/ directory has permissions 700
# ---------------------------------------------------------------------------
@test "models/ directory has permissions 700" {
    run "${MODEL_STORE_SCRIPT}"

    [ "$status" -eq 0 ]

    # stat -c %a prints octal permissions on Linux
    run stat -c '%a' "${OLDINTELCLAW_HOME}/models"
    [ "$status" -eq 0 ]
    [ "$output" = "700" ]
}

# ---------------------------------------------------------------------------
# Test 6: Dry run — prints plan, no directories created
# ---------------------------------------------------------------------------
@test "Dry run: prints plan to stdout, no directories created" {
    export OLDINTELCLAW_DRY_RUN="1"

    run "${MODEL_STORE_SCRIPT}"

    [ "$status" -eq 0 ]
    # Output must mention the key paths
    [[ "$output" == *"models"* ]]
    [[ "$output" == *"PLAN"* ]] || [[ "$output" == *"DRY"* ]]

    # No directories must have been created under models/
    [ ! -d "${OLDINTELCLAW_HOME}/models" ]
}
