#!/usr/bin/env bats
# Unit tests for scripts/install/python_itrex.sh — Story 2.5: Python + ITREX Install
#
# All external commands are overridden via env vars so tests never need real
# Python, pip, or a real venv.  Each env var defaults to the real command but
# can be set to `true` (success, no output), `false` (failure), or
# `echo <string>` (success with controlled output).

load '../test_helper'

INSTALL_SCRIPT="${SCRIPTS_DIR}/install/python_itrex.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Point all overrides at "everything works, ITREX already installed"
setup_python313_itrex_installed() {
    export OLDINTELCLAW_CMD_PYTHON_CHECK="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.13.0"
    export OLDINTELCLAW_CMD_ITREX_CHECK="true"
    export OLDINTELCLAW_CMD_VENV_CREATE="true"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_VENV_DIR="${BATS_TMPDIR}/existing_venv"
    mkdir -p "${OLDINTELCLAW_VENV_DIR}"
}

# Point all overrides at "Python 3.13 present, ITREX missing, install succeeds"
setup_python313_itrex_missing_install_ok() {
    export OLDINTELCLAW_CMD_PYTHON_CHECK="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.13.0"
    export OLDINTELCLAW_CMD_ITREX_CHECK="false"
    export OLDINTELCLAW_CMD_ITREX_VERIFY="true"
    export OLDINTELCLAW_CMD_VENV_CREATE="true"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_VENV_DIR="${BATS_TMPDIR}/new_venv_ok"
}

# ---------------------------------------------------------------------------
# Test 1: Python 3.13 present, ITREX already installed → SKIP install, exits 0
# ---------------------------------------------------------------------------
@test "Python 3.13 present, ITREX already installed — skips install, exits 0" {
    setup_python313_itrex_installed

    run "${INSTALL_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]] || [[ "$output" == *"already installed"* ]]
    [[ "$output" == *"Python"* ]]
    [[ "$output" == *"3.13"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Python 3.13 present, ITREX missing, install succeeds → INSTALLED, exits 0
# ---------------------------------------------------------------------------
@test "Python 3.13 present, ITREX missing, install succeeds — prints INSTALLED, exits 0" {
    setup_python313_itrex_missing_install_ok

    run "${INSTALL_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALLED"* ]] || [[ "$output" == *"installed"* ]]
    [[ "$output" == *"Python"* ]]
    [[ "$output" == *"ITREX"* ]] || [[ "$output" == *"itrex"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Python 3.10 present → FAIL with version error, exits 1
# ---------------------------------------------------------------------------
@test "Python 3.10 present — fails with version error, exits 1" {
    export OLDINTELCLAW_CMD_PYTHON_CHECK="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.10.0"
    export OLDINTELCLAW_CMD_ITREX_CHECK="false"
    export OLDINTELCLAW_CMD_VENV_CREATE="true"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_VENV_DIR="${BATS_TMPDIR}/venv_py310"

    run "${INSTALL_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]] || [[ "$output" == *"3.12"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: No Python present → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "No Python present — fails, exits 1" {
    export OLDINTELCLAW_CMD_PYTHON_CHECK="false"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="false"
    export OLDINTELCLAW_CMD_ITREX_CHECK="false"
    export OLDINTELCLAW_CMD_VENV_CREATE="true"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_VENV_DIR="${BATS_TMPDIR}/venv_nopy"

    run "${INSTALL_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]] || [[ "$output" == *"python"* ]] || [[ "$output" == *"Python"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Venv directory already exists — does not call venv create command
# ---------------------------------------------------------------------------
@test "Venv directory already exists — does not recreate venv" {
    export OLDINTELCLAW_CMD_PYTHON_CHECK="true"
    export OLDINTELCLAW_CMD_PYTHON_VERSION="echo Python 3.13.0"
    export OLDINTELCLAW_CMD_ITREX_CHECK="true"
    # Use a sentinel: if this command runs, it writes a marker file
    local marker="${BATS_TMPDIR}/venv_create_ran"
    export OLDINTELCLAW_CMD_VENV_CREATE="touch ${marker} ; true"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_VENV_DIR="${BATS_TMPDIR}/preexisting_venv"
    mkdir -p "${OLDINTELCLAW_VENV_DIR}"

    run "${INSTALL_SCRIPT}"

    [ "$status" -eq 0 ]
    # The venv-create command must NOT have run because the dir already existed
    [ ! -f "${marker}" ]
}

# ---------------------------------------------------------------------------
# Test 6: pip install fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "pip install fails — prints FAIL, exits 1" {
    setup_python313_itrex_missing_install_ok
    # Override pip to fail
    export OLDINTELCLAW_CMD_PIP_INSTALL="false"

    run "${INSTALL_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Dry-run mode — prints plan, does not install
# ---------------------------------------------------------------------------
@test "Dry-run mode — prints plan, does not install" {
    setup_python313_itrex_missing_install_ok
    # Override pip to fail so that if it runs for real the test catches it
    export OLDINTELCLAW_CMD_PIP_INSTALL="false"
    export OLDINTELCLAW_DRY_RUN="1"

    run "${INSTALL_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"dry"* ]] || [[ "$output" == *"DRY"* ]] || [[ "$output" == *"plan"* ]] || [[ "$output" == *"PLAN"* ]]
}
