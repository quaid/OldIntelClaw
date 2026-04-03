#!/usr/bin/env bats
# Unit tests for scripts/install/openvino.sh — Story 2.2: Install OpenVINO Toolkit
#
# Uses env var overrides so tests never need real pip/python/venv.
#   OLDINTELCLAW_CMD_OPENVINO_CHECK   — override openvino import check
#   OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK — override GPU device check
#   OLDINTELCLAW_CMD_PIP_INSTALL      — override pip install
#   OLDINTELCLAW_VENV_DIR             — override venv path
#   OLDINTELCLAW_CMD_VENV_CREATE      — override python3 -m venv

load '../test_helper'

OPENVINO_SCRIPT="${SCRIPTS_DIR}/install/openvino.sh"

setup() {
    # Use a temp dir for venv so tests don't touch the real filesystem
    export OLDINTELCLAW_VENV_DIR="$(mktemp -d /tmp/oldintelclaw_venv_XXXXXX)"
    # Default: openvino not installed
    export OLDINTELCLAW_CMD_OPENVINO_CHECK="false"
    # Default: GPU available
    export OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK="true"
    # Default: pip install succeeds
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    # Default: venv creation succeeds (just mkdir to simulate)
    export OLDINTELCLAW_CMD_VENV_CREATE="mkdir -p"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${OLDINTELCLAW_VENV_DIR}" 2>/dev/null || true
    unset OLDINTELCLAW_VENV_DIR
    unset OLDINTELCLAW_CMD_OPENVINO_CHECK
    unset OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK
    unset OLDINTELCLAW_CMD_PIP_INSTALL
    unset OLDINTELCLAW_CMD_VENV_CREATE
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: OpenVINO already installed — SKIP, exits 0
# ---------------------------------------------------------------------------
@test "OpenVINO already installed — SKIP and exits 0" {
    export OLDINTELCLAW_CMD_OPENVINO_CHECK="true"

    run "${OPENVINO_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    # Should not attempt install
    [[ "$output" != *"INSTALLED"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh install succeeds and GPU is available — INSTALLED + GPU PASS, exits 0
# ---------------------------------------------------------------------------
@test "Fresh install succeeds with GPU available — INSTALLED and GPU PASS and exits 0" {
    export OLDINTELCLAW_CMD_OPENVINO_CHECK="false"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK="true"

    run "${OPENVINO_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALLED"* ]]
    # GPU check must show a positive result
    [[ "$output" == *"GPU"* ]]
    [[ "$output" != *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Install succeeds but no GPU device — INSTALLED + GPU WARN, exits 0
# ---------------------------------------------------------------------------
@test "Install succeeds but no GPU device — INSTALLED with GPU WARN and exits 0" {
    export OLDINTELCLAW_CMD_OPENVINO_CHECK="false"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK="false"

    run "${OPENVINO_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALLED"* ]]
    # GPU not available is a warning, not a failure
    [[ "$output" == *"WARN"* ]]
    [[ "$output" != *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Install fails — FAIL, exits 1
# ---------------------------------------------------------------------------
@test "pip install fails — FAIL and exits 1" {
    export OLDINTELCLAW_CMD_OPENVINO_CHECK="false"
    export OLDINTELCLAW_CMD_PIP_INSTALL="false"

    run "${OPENVINO_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run mode — prints plan, no install executed
# ---------------------------------------------------------------------------
@test "Dry run mode — prints plan without executing install" {
    export OLDINTELCLAW_CMD_OPENVINO_CHECK="false"
    export OLDINTELCLAW_DRY_RUN="1"
    # Set pip to false so if it runs it causes failure
    export OLDINTELCLAW_CMD_PIP_INSTALL="false"

    run "${OPENVINO_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" != *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: Venv already exists — doesn't recreate (venv-create not called again)
# ---------------------------------------------------------------------------
@test "Venv already exists — skips venv creation and proceeds" {
    # Pre-create the venv dir to simulate it already existing
    mkdir -p "${OLDINTELCLAW_VENV_DIR}"

    # Use a venv-create command that would fail if called, proving we skip it
    local fail_script
    fail_script="$(mktemp /tmp/fail_venv_XXXXXX)"
    cat > "${fail_script}" <<'EOF'
#!/usr/bin/env bash
echo "ERROR: venv creation should not be called when venv already exists" >&2
exit 1
EOF
    chmod +x "${fail_script}"
    export OLDINTELCLAW_CMD_VENV_CREATE="${fail_script}"

    export OLDINTELCLAW_CMD_OPENVINO_CHECK="false"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK="true"

    run "${OPENVINO_SCRIPT}"

    rm -f "${fail_script}"

    [ "$status" -eq 0 ]
    [[ "$output" != *"ERROR: venv creation should not be called"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Summary output mentions openvino and openvino-genai packages
# ---------------------------------------------------------------------------
@test "Install output mentions openvino and openvino-genai packages" {
    export OLDINTELCLAW_CMD_OPENVINO_CHECK="false"
    export OLDINTELCLAW_CMD_PIP_INSTALL="true"
    export OLDINTELCLAW_CMD_OPENVINO_GPU_CHECK="true"

    run "${OPENVINO_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"openvino"* ]]
    [[ "$output" == *"openvino-genai"* ]]
}
