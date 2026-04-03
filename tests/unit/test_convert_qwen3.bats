#!/usr/bin/env bats
# Unit tests for scripts/models/convert_qwen3.sh — Story 4.6
# Qwen3-8B-Thinking INT4 quantization pipeline for ITREX CPU
#
# Mocking strategy:
#   OLDINTELCLAW_CMD_DOWNLOAD        — replaced with script that creates a dummy file
#   OLDINTELCLAW_CMD_ITREX_QUANTIZE  — replaced with `true` (success) or `false` (failure)
#   OLDINTELCLAW_CMD_ITREX_VERIFY    — replaced with `true` (success) or `false` (failure)
#   OLDINTELCLAW_HOME                — pointed at a temp dir with a fresh manifest.json

load '../test_helper'

CONVERT_SCRIPT="${SCRIPTS_DIR}/models/convert_qwen3.sh"
MODEL_NAME="qwen3-8b"

setup() {
    export OLDINTELCLAW_HOME="$(mktemp -d /tmp/oldintelclaw_home_XXXXXX)"

    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<'EOF'
{"version":1,"models":{}}
EOF

    # Mock download: creates a dummy file at the output path
    _mock_download_ok="$(mktemp /tmp/mock_dl_ok_XXXXXX)"
    cat > "${_mock_download_ok}" <<'MOCK'
#!/usr/bin/env bash
output_path=""
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-o" ]]; then
        output_path="$2"
        shift 2
    else
        shift
    fi
done
if [[ -n "${output_path}" ]]; then
    mkdir -p "$(dirname "${output_path}")"
    echo "dummy model data" > "${output_path}"
fi
exit 0
MOCK
    chmod +x "${_mock_download_ok}"
    export _MOCK_DOWNLOAD_OK="${_mock_download_ok}"

    # Mock download that always fails
    _mock_download_fail="$(mktemp /tmp/mock_dl_fail_XXXXXX)"
    cat > "${_mock_download_fail}" <<'MOCK'
#!/usr/bin/env bash
echo "download failed" >&2
exit 1
MOCK
    chmod +x "${_mock_download_fail}"
    export _MOCK_DOWNLOAD_FAIL="${_mock_download_fail}"

    # Default overrides: everything succeeds
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_OK} -o"
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
@test "qwen3-8b already registered in manifest — prints SKIP, exits 0" {
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<EOF
{"version":1,"models":{"${MODEL_NAME}":{"backend":"itrex-cpu","path":"${OLDINTELCLAW_HOME}/models/itrex/qwen3-8b","size_gb":"5.5","registered":"2026-01-01T00:00:00Z"}}}
EOF

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh quantization succeeds → registered in manifest, exits 0
# ---------------------------------------------------------------------------
@test "Fresh qwen3-8b quantization succeeds — registered in manifest, exits 0" {
    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    grep -q '"qwen3-8b"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"itrex-cpu"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"5.5"' "${OLDINTELCLAW_HOME}/manifest.json"
}

# ---------------------------------------------------------------------------
# Test 3: Download fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "qwen3-8b download fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Quantization fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "qwen3-8b ITREX quantization fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_ITREX_QUANTIZE="false"

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run → no download performed
# ---------------------------------------------------------------------------
@test "qwen3-8b dry run — prints DRY RUN, no download performed, exits 0" {
    export OLDINTELCLAW_DRY_RUN="1"
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" != *"FAIL"* ]]
}
