#!/usr/bin/env bats
# Unit tests for scripts/audit/installed.sh — Story 1.4: Existing Installation Detection
#
# Uses env var overrides for each component command so tests never need real
# tool installations.  Set a var to `true` to simulate installed, `false` to
# simulate missing.

load '../test_helper'

INSTALLED_SCRIPT="${SCRIPTS_DIR}/audit/installed.sh"

# ---------------------------------------------------------------------------
# Helper: point every command override at `true` (all installed)
# ---------------------------------------------------------------------------
setup_all_installed() {
    export OLDINTELCLAW_CMD_OPENVINO="true"
    export OLDINTELCLAW_CMD_RUST="true"
    export OLDINTELCLAW_CMD_ZEROCLAW="true"
    export OLDINTELCLAW_CMD_PYTHON="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.12.0"
    export OLDINTELCLAW_CMD_ITREX="true"
}

# ---------------------------------------------------------------------------
# Helper: point every command override at `false` (all missing)
# ---------------------------------------------------------------------------
setup_all_missing() {
    export OLDINTELCLAW_CMD_OPENVINO="false"
    export OLDINTELCLAW_CMD_RUST="false"
    export OLDINTELCLAW_CMD_ZEROCLAW="false"
    export OLDINTELCLAW_CMD_PYTHON="false"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="false"
    export OLDINTELCLAW_CMD_ITREX="false"
}

# ---------------------------------------------------------------------------
# Test 1: All components installed — exits 0, all show INSTALLED
# ---------------------------------------------------------------------------
@test "All components installed — exits 0 and all show INSTALLED" {
    setup_all_installed

    run "${INSTALLED_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALLED"* ]]
    [[ "$output" == *"OpenVINO"* ]]
    [[ "$output" == *"Rust"* ]]
    [[ "$output" == *"ZeroClaw"* ]]
    [[ "$output" == *"Python"* ]]
    [[ "$output" == *"ITREX"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: All components missing — exits 0 (detection only), all show MISSING
# ---------------------------------------------------------------------------
@test "All components missing — exits 0 and all show MISSING" {
    setup_all_missing

    run "${INSTALLED_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"MISSING"* ]]
    [[ "$output" == *"OpenVINO"* ]]
    [[ "$output" == *"Rust"* ]]
    [[ "$output" == *"ZeroClaw"* ]]
    [[ "$output" == *"Python"* ]]
    [[ "$output" == *"ITREX"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Partial install — Rust present, OpenVINO missing
# ---------------------------------------------------------------------------
@test "Partial install: Rust shows INSTALLED, OpenVINO shows MISSING" {
    export OLDINTELCLAW_CMD_OPENVINO="false"
    export OLDINTELCLAW_CMD_RUST="true"
    export OLDINTELCLAW_CMD_ZEROCLAW="false"
    export OLDINTELCLAW_CMD_PYTHON="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.12.0"
    export OLDINTELCLAW_CMD_ITREX="false"

    run "${INSTALLED_SCRIPT}"

    [ "$status" -eq 0 ]

    # Rust line must contain INSTALLED
    rust_line="$(echo "$output" | grep -i "Rust")"
    [[ "$rust_line" == *"INSTALLED"* ]]

    # OpenVINO line must contain MISSING
    openvino_line="$(echo "$output" | grep -i "OpenVINO")"
    [[ "$openvino_line" == *"MISSING"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Python present but version is 3.10.0 — show WARN for Python version
# ---------------------------------------------------------------------------
@test "Python 3.10 present — Python version shows WARN" {
    export OLDINTELCLAW_CMD_OPENVINO="false"
    export OLDINTELCLAW_CMD_RUST="false"
    export OLDINTELCLAW_CMD_ZEROCLAW="false"
    export OLDINTELCLAW_CMD_PYTHON="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.10.0"
    export OLDINTELCLAW_CMD_ITREX="false"

    run "${INSTALLED_SCRIPT}"

    [ "$status" -eq 0 ]

    # The Python version line must show WARN (not INSTALLED) because 3.10 < 3.12
    python_version_line="$(echo "$output" | grep -i "Python" | grep -iE "WARN|version")"
    [[ "$python_version_line" == *"WARN"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Output includes a summary count line
# ---------------------------------------------------------------------------
@test "Output includes a summary count line with N/5 format" {
    setup_all_installed

    run "${INSTALLED_SCRIPT}"

    [ "$status" -eq 0 ]
    # Summary must show total out of 5 in a "N/5" pattern
    [[ "$output" =~ [0-9]/5 ]]
}

# ---------------------------------------------------------------------------
# Test 6: Summary count is accurate — 1 of 5 installed
# ---------------------------------------------------------------------------
@test "Summary count is accurate when only Rust is installed — shows 1/5" {
    export OLDINTELCLAW_CMD_OPENVINO="false"
    export OLDINTELCLAW_CMD_RUST="true"
    export OLDINTELCLAW_CMD_ZEROCLAW="false"
    export OLDINTELCLAW_CMD_PYTHON="false"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="false"
    export OLDINTELCLAW_CMD_ITREX="false"

    run "${INSTALLED_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1/5"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Summary count is accurate — all 5 installed
# ---------------------------------------------------------------------------
@test "Summary count is accurate when all components installed — shows 5/5" {
    setup_all_installed

    run "${INSTALLED_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"5/5"* ]]
}
