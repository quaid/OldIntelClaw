#!/usr/bin/env bats
# Unit tests for scripts/migrate/detect.sh — Story 3.3: OpenClaw Migration Detection
#
# Uses OLDINTELCLAW_OPENCLAW_PATHS env var override so tests never touch real
# home directory paths. Temp dirs are created in setup() and removed in teardown().

load '../test_helper'

DETECT_SCRIPT="${SCRIPTS_DIR}/migrate/detect.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# Test 1: No OpenClaw files present — reports not found, OPENCLAW_FOUND=false, exits 0
# ---------------------------------------------------------------------------
@test "No OpenClaw files present: prints info, OPENCLAW_FOUND=false, exits 0" {
    # Point paths at non-existent locations within temp dir
    local absent_a="${TEST_TMPDIR}/no_openclaw_dir"
    local absent_b="${TEST_TMPDIR}/no_SKILL.md"
    local absent_c="${TEST_TMPDIR}/no_openclaw.yaml"

    export OLDINTELCLAW_OPENCLAW_PATHS="${absent_a}:${absent_b}:${absent_c}"

    run "${DETECT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No OpenClaw files detected"* ]]
    [[ "$output" == *"OPENCLAW_FOUND=false"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: ~/.openclaw/ directory exists — reports it, OPENCLAW_FOUND=true, exits 0
# ---------------------------------------------------------------------------
@test "openclaw directory exists: reports it, OPENCLAW_FOUND=true, exits 0" {
    local openclaw_dir="${TEST_TMPDIR}/.openclaw"
    mkdir -p "${openclaw_dir}"

    export OLDINTELCLAW_OPENCLAW_PATHS="${openclaw_dir}"

    run "${DETECT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"${openclaw_dir}"* ]]
    [[ "$output" == *"OPENCLAW_FOUND=true"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: ./SKILL.md file exists — reports it, OPENCLAW_FOUND=true, exits 0
# ---------------------------------------------------------------------------
@test "SKILL.md file exists: reports it, OPENCLAW_FOUND=true, exits 0" {
    local skill_file="${TEST_TMPDIR}/SKILL.md"
    touch "${skill_file}"

    export OLDINTELCLAW_OPENCLAW_PATHS="${skill_file}"

    run "${DETECT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"${skill_file}"* ]]
    [[ "$output" == *"OPENCLAW_FOUND=true"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: ./openclaw.yaml file exists — reports it, OPENCLAW_FOUND=true, exits 0
# ---------------------------------------------------------------------------
@test "openclaw.yaml file exists: reports it, OPENCLAW_FOUND=true, exits 0" {
    local yaml_file="${TEST_TMPDIR}/openclaw.yaml"
    touch "${yaml_file}"

    export OLDINTELCLAW_OPENCLAW_PATHS="${yaml_file}"

    run "${DETECT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"${yaml_file}"* ]]
    [[ "$output" == *"OPENCLAW_FOUND=true"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Multiple files found — reports all of them
# ---------------------------------------------------------------------------
@test "Multiple OpenClaw files found: reports all locations, OPENCLAW_FOUND=true" {
    local skill_file="${TEST_TMPDIR}/SKILL.md"
    local yaml_file="${TEST_TMPDIR}/openclaw.yaml"
    local openclaw_dir="${TEST_TMPDIR}/.openclaw"
    touch "${skill_file}"
    touch "${yaml_file}"
    mkdir -p "${openclaw_dir}"

    export OLDINTELCLAW_OPENCLAW_PATHS="${skill_file}:${yaml_file}:${openclaw_dir}"

    run "${DETECT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"${skill_file}"* ]]
    [[ "$output" == *"${yaml_file}"* ]]
    [[ "$output" == *"${openclaw_dir}"* ]]
    [[ "$output" == *"OPENCLAW_FOUND=true"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: Always exits 0 regardless of what is found or not found
# ---------------------------------------------------------------------------
@test "Always exits 0 regardless of findings" {
    # Mix of existing and non-existing paths
    local real_file="${TEST_TMPDIR}/openclaw.yaml"
    local fake_path="${TEST_TMPDIR}/does_not_exist"
    touch "${real_file}"

    export OLDINTELCLAW_OPENCLAW_PATHS="${real_file}:${fake_path}"

    run "${DETECT_SCRIPT}"

    [ "$status" -eq 0 ]
}
