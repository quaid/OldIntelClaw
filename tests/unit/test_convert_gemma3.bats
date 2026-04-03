#!/usr/bin/env bats
# Unit tests for scripts/models/convert_gemma3.sh — Story 4.5
# Gemma 3 4B INT4 conversion pipeline for OpenVINO iGPU
#
# Mocking strategy:
#   OLDINTELCLAW_CMD_DOWNLOAD      — replaced with script that creates a dummy file
#   OLDINTELCLAW_CMD_OV_CONVERT    — replaced with `true` (success) or `false` (failure)
#   OLDINTELCLAW_CMD_OV_VERIFY     — replaced with `true` (success) or `false` (failure)
#   OLDINTELCLAW_HOME              — pointed at a temp dir with a fresh manifest.json

load '../test_helper'

CONVERT_SCRIPT="${SCRIPTS_DIR}/models/convert_gemma3.sh"
MODEL_NAME="gemma-3-4b"

setup() {
    export OLDINTELCLAW_HOME="$(mktemp -d /tmp/oldintelclaw_home_XXXXXX)"

    # Minimal valid manifest (version field required by store.sh convention)
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
@test "gemma-3-4b already registered in manifest — prints SKIP, exits 0" {
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<EOF
{"version":1,"models":{"${MODEL_NAME}":{"backend":"openvino-igpu","path":"${OLDINTELCLAW_HOME}/models/openvino/gemma-3-4b","size_gb":"3.2","registered":"2026-01-01T00:00:00Z"}}}
EOF

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh conversion succeeds → registered in manifest, exits 0
# ---------------------------------------------------------------------------
@test "Fresh gemma-3-4b conversion succeeds — registered in manifest, exits 0" {
    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    grep -q '"gemma-3-4b"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"openvino-igpu"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"3.2"' "${OLDINTELCLAW_HOME}/manifest.json"
}

# ---------------------------------------------------------------------------
# Test 3: Download fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "gemma-3-4b download fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Conversion fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "gemma-3-4b OpenVINO conversion fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_OV_CONVERT="false"

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run → no download performed
# ---------------------------------------------------------------------------
@test "gemma-3-4b dry run — prints DRY RUN, no download performed, exits 0" {
    export OLDINTELCLAW_DRY_RUN="1"
    # Use failing download so any real download attempt would surface as a failure
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run "${CONVERT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" != *"FAIL"* ]]
}
