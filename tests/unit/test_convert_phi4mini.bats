#!/usr/bin/env bats
# Unit tests for scripts/models/convert_phi4mini.sh — Story 4.3
#
# Tests the full Phi-4-mini INT4 → OpenVINO iGPU pipeline:
#   1. Model already registered → SKIP, exits 0
#   2. Fresh conversion succeeds → INSTALLED/PASS, exits 0, registered in manifest
#   3. Download fails → FAIL, exits 1
#   4. Conversion fails → FAIL, exits 1
#   5. Dry run → prints plan, no download or conversion
#
# Mocking strategy:
#   OLDINTELCLAW_CMD_DOWNLOAD      — temp script that creates a dummy file (ok)
#                                    or a script that exits 1 (fail)
#   OLDINTELCLAW_CMD_OV_CONVERT    — "true" (success) or "false" (failure)
#   OLDINTELCLAW_CMD_OV_VERIFY     — always "true"
#   OLDINTELCLAW_HOME              — temp dir with pre-created manifest.json

load '../test_helper'

CONVERT_PHI4_SCRIPT="${SCRIPTS_DIR}/models/convert_phi4mini.sh"

setup() {
    # Isolated temp home for each test
    export OLDINTELCLAW_HOME="$(mktemp -d /tmp/oldintelclaw_phi4_XXXXXX)"

    # Minimal valid manifest — empty models object
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<'EOF'
{
  "version": 1,
  "models": {}
}
EOF

    # Mock download — success: creates a dummy sentinel file
    _mock_download_ok="$(mktemp /tmp/mock_dl_ok_XXXXXX)"
    cat > "${_mock_download_ok}" <<'MOCK'
#!/usr/bin/env bash
# Receives: <output_file> <url>
# Create the output file to simulate a completed download
output_file="$1"
mkdir -p "$(dirname "${output_file}")"
echo "dummy phi4mini model data" > "${output_file}"
exit 0
MOCK
    chmod +x "${_mock_download_ok}"
    export _MOCK_DOWNLOAD_OK="${_mock_download_ok}"

    # Mock download — failure
    _mock_download_fail="$(mktemp /tmp/mock_dl_fail_XXXXXX)"
    cat > "${_mock_download_fail}" <<'MOCK'
#!/usr/bin/env bash
echo "download: connection refused" >&2
exit 1
MOCK
    chmod +x "${_mock_download_fail}"
    export _MOCK_DOWNLOAD_FAIL="${_mock_download_fail}"

    # Default overrides: success path
    export OLDINTELCLAW_CMD_DOWNLOAD="${_mock_download_ok}"
    export OLDINTELCLAW_CMD_OV_CONVERT="true"
    export OLDINTELCLAW_CMD_OV_VERIFY="true"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${OLDINTELCLAW_HOME}" 2>/dev/null || true
    rm -f "${_MOCK_DOWNLOAD_OK}" "${_MOCK_DOWNLOAD_FAIL}" 2>/dev/null || true
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CMD_DOWNLOAD
    unset OLDINTELCLAW_CMD_OV_CONVERT
    unset OLDINTELCLAW_CMD_OV_VERIFY
    unset OLDINTELCLAW_DRY_RUN
    unset _MOCK_DOWNLOAD_OK _MOCK_DOWNLOAD_FAIL
}

# ---------------------------------------------------------------------------
# Test 1: Model already registered → SKIP, exits 0
# ---------------------------------------------------------------------------
@test "phi-4-mini already registered in manifest — prints SKIP, exits 0" {
    # Pre-populate manifest with the model entry
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<EOF
{
  "version": 1,
  "models": {
    "phi-4-mini": {
      "backend": "openvino-igpu",
      "path": "${OLDINTELCLAW_HOME}/models/openvino/phi-4-mini",
      "size_gb": "3.0",
      "registered": "2026-01-01T00:00:00Z"
    }
  }
}
EOF

    run "${CONVERT_PHI4_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh conversion succeeds → PASS/INSTALLED, exits 0, registered
# ---------------------------------------------------------------------------
@test "Fresh phi-4-mini conversion — prints PASS, exits 0, registers in manifest" {
    export OLDINTELCLAW_CMD_OV_CONVERT="true"
    export OLDINTELCLAW_CMD_OV_VERIFY="true"

    run "${CONVERT_PHI4_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"INSTALLED"* ]]

    # Model must be registered in manifest
    grep -q '"phi-4-mini"' "${OLDINTELCLAW_HOME}/manifest.json"
}

# ---------------------------------------------------------------------------
# Test 3: Download fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "phi-4-mini download fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL}"

    run "${CONVERT_PHI4_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Conversion fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "phi-4-mini OpenVINO conversion fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_OV_CONVERT="false"

    run "${CONVERT_PHI4_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run → prints plan, no download or conversion
# ---------------------------------------------------------------------------
@test "phi-4-mini dry run — prints plan, no download or conversion executed" {
    export OLDINTELCLAW_DRY_RUN="1"
    # Use failing download so that if it runs at all the test catches it
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL}"
    export OLDINTELCLAW_CMD_OV_CONVERT="false"

    run "${CONVERT_PHI4_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]] || [[ "$output" == *"PLAN"* ]]
    # Must not print FAIL (which would indicate a real command ran and failed)
    [[ "$output" != *"FAIL"* ]]
    # Manifest must remain empty — model must not be registered
    ! grep -q '"phi-4-mini"' "${OLDINTELCLAW_HOME}/manifest.json"
}
