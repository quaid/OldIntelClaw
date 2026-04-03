#!/usr/bin/env bats
# Unit tests for scripts/models/convert_deepseek_r1.sh — Story 4.4
#
# Tests the full DeepSeek-R1-Distill-Qwen-7B INT4 → ITREX CPU pipeline:
#   1. Model already registered → SKIP, exits 0
#   2. Fresh quantization succeeds → INSTALLED/PASS, exits 0, registered in manifest
#   3. Download fails → FAIL, exits 1
#   4. Quantization fails → FAIL, exits 1
#   5. Dry run → prints plan, no download or quantization
#
# Mocking strategy:
#   OLDINTELCLAW_CMD_DOWNLOAD        — temp script that creates a dummy file (ok)
#                                      or a script that exits 1 (fail)
#   OLDINTELCLAW_CMD_ITREX_QUANTIZE  — "true" (success) or "false" (failure)
#   OLDINTELCLAW_CMD_ITREX_VERIFY    — always "true"
#   OLDINTELCLAW_HOME                — temp dir with pre-created manifest.json

load '../test_helper'

CONVERT_DEEPSEEK_SCRIPT="${SCRIPTS_DIR}/models/convert_deepseek_r1.sh"

setup() {
    # Isolated temp home for each test
    export OLDINTELCLAW_HOME="$(mktemp -d /tmp/oldintelclaw_deepseek_XXXXXX)"

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
echo "dummy deepseek r1 model data" > "${output_file}"
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
    export OLDINTELCLAW_CMD_ITREX_QUANTIZE="true"
    export OLDINTELCLAW_CMD_ITREX_VERIFY="true"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${OLDINTELCLAW_HOME}" 2>/dev/null || true
    rm -f "${_MOCK_DOWNLOAD_OK}" "${_MOCK_DOWNLOAD_FAIL}" 2>/dev/null || true
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CMD_DOWNLOAD
    unset OLDINTELCLAW_CMD_ITREX_QUANTIZE
    unset OLDINTELCLAW_CMD_ITREX_VERIFY
    unset OLDINTELCLAW_DRY_RUN
    unset _MOCK_DOWNLOAD_OK _MOCK_DOWNLOAD_FAIL
}

# ---------------------------------------------------------------------------
# Test 1: Model already registered → SKIP, exits 0
# ---------------------------------------------------------------------------
@test "deepseek-r1-7b already registered in manifest — prints SKIP, exits 0" {
    # Pre-populate manifest with the model entry
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<EOF
{
  "version": 1,
  "models": {
    "deepseek-r1-7b": {
      "backend": "itrex-cpu",
      "path": "${OLDINTELCLAW_HOME}/models/itrex/deepseek-r1-7b",
      "size_gb": "5.2",
      "registered": "2026-01-01T00:00:00Z"
    }
  }
}
EOF

    run "${CONVERT_DEEPSEEK_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh quantization succeeds → PASS/INSTALLED, exits 0, registered
# ---------------------------------------------------------------------------
@test "Fresh deepseek-r1-7b quantization — prints PASS, exits 0, registers in manifest" {
    export OLDINTELCLAW_CMD_ITREX_QUANTIZE="true"
    export OLDINTELCLAW_CMD_ITREX_VERIFY="true"

    run "${CONVERT_DEEPSEEK_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"INSTALLED"* ]]

    # Model must be registered in manifest
    grep -q '"deepseek-r1-7b"' "${OLDINTELCLAW_HOME}/manifest.json"
}

# ---------------------------------------------------------------------------
# Test 3: Download fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "deepseek-r1-7b download fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL}"

    run "${CONVERT_DEEPSEEK_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Quantization fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "deepseek-r1-7b ITREX quantization fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_ITREX_QUANTIZE="false"

    run "${CONVERT_DEEPSEEK_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run → prints plan, no download or quantization
# ---------------------------------------------------------------------------
@test "deepseek-r1-7b dry run — prints plan, no download or quantization executed" {
    export OLDINTELCLAW_DRY_RUN="1"
    # Use failing download so that if it runs at all the test catches it
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL}"
    export OLDINTELCLAW_CMD_ITREX_QUANTIZE="false"

    run "${CONVERT_DEEPSEEK_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]] || [[ "$output" == *"PLAN"* ]]
    # Must not print FAIL (which would indicate a real command ran and failed)
    [[ "$output" != *"FAIL"* ]]
    # Manifest must remain empty — model must not be registered
    ! grep -q '"deepseek-r1-7b"' "${OLDINTELCLAW_HOME}/manifest.json"
}
