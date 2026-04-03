#!/usr/bin/env bats
# Unit tests for scripts/models/download_smollm3.sh — Story 4.7
# SmolLM3-3B GGUF download pipeline for ZeroClaw Native
#
# No conversion step — pure download and verify.
#
# Mocking strategy:
#   OLDINTELCLAW_CMD_DOWNLOAD — replaced with script that creates a dummy file
#   OLDINTELCLAW_HOME         — pointed at a temp dir with a fresh manifest.json

load '../test_helper'

DOWNLOAD_SCRIPT="${SCRIPTS_DIR}/models/download_smollm3.sh"
MODEL_NAME="smollm3-3b"

setup() {
    export OLDINTELCLAW_HOME="$(mktemp -d /tmp/oldintelclaw_home_XXXXXX)"

    # Minimal valid manifest in the multi-line format register_model expects
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<'EOF'
{
  "version": 1,
  "models": {}
}
EOF

    # Mock download: creates a non-empty dummy GGUF file at the output path
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
    echo "dummy gguf model data" > "${output_path}"
fi
exit 0
MOCK
    chmod +x "${_mock_download_ok}"
    export _MOCK_DOWNLOAD_OK="${_mock_download_ok}"

    # Mock download that always fails (creates no file)
    _mock_download_fail="$(mktemp /tmp/mock_dl_fail_XXXXXX)"
    cat > "${_mock_download_fail}" <<'MOCK'
#!/usr/bin/env bash
echo "download failed" >&2
exit 1
MOCK
    chmod +x "${_mock_download_fail}"
    export _MOCK_DOWNLOAD_FAIL="${_mock_download_fail}"

    # Default: download succeeds
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_OK} -o"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${OLDINTELCLAW_HOME}" 2>/dev/null || true
    rm -f "${_MOCK_DOWNLOAD_OK}" "${_MOCK_DOWNLOAD_FAIL}" 2>/dev/null || true
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CMD_DOWNLOAD
    unset OLDINTELCLAW_DRY_RUN
    unset _MOCK_DOWNLOAD_OK _MOCK_DOWNLOAD_FAIL
}

# ---------------------------------------------------------------------------
# Test 1: Model already registered → SKIP, exits 0
# ---------------------------------------------------------------------------
@test "smollm3-3b already registered in manifest — prints SKIP, exits 0" {
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<EOF
{
  "version": 1,
  "models": {
    "${MODEL_NAME}": {
      "backend": "gguf-native",
      "path": "${OLDINTELCLAW_HOME}/models/gguf/smollm3-3b.gguf",
      "size_gb": "2.2",
      "registered": "2026-01-01T00:00:00Z"
    }
  }
}
EOF

    run "${DOWNLOAD_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Fresh download succeeds → registered in manifest, exits 0
# ---------------------------------------------------------------------------
@test "Fresh smollm3-3b download succeeds — registered in manifest, exits 0" {
    run "${DOWNLOAD_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    grep -q '"smollm3-3b"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"gguf-native"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"2.2"' "${OLDINTELCLAW_HOME}/manifest.json"
}

# ---------------------------------------------------------------------------
# Test 3: Download fails → FAIL, exits 1
# ---------------------------------------------------------------------------
@test "smollm3-3b download fails — prints FAIL, exits 1" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run "${DOWNLOAD_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Dry run → no download performed
# ---------------------------------------------------------------------------
@test "smollm3-3b dry run — prints DRY RUN, no download performed, exits 0" {
    export OLDINTELCLAW_DRY_RUN="1"
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run "${DOWNLOAD_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" != *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Downloaded GGUF file is verified non-empty
# ---------------------------------------------------------------------------
@test "smollm3-3b verifies downloaded GGUF file is non-empty — PASS, exits 0" {
    run "${DOWNLOAD_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]

    # The GGUF file must exist and be non-empty
    local gguf_file="${OLDINTELCLAW_HOME}/models/gguf/smollm3-3b.gguf"
    [ -f "${gguf_file}" ]
    [ -s "${gguf_file}" ]
}
