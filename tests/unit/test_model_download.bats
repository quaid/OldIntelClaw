#!/usr/bin/env bats
# Unit tests for scripts/models/download.sh — Story 4.2: Model Download Engine
#
# Tests source download.sh directly to access its library functions:
#   download_model MODEL_NAME HF_REPO OUTPUT_DIR [EXPECTED_SHA256]
#   register_model MODEL_NAME BACKEND PATH SIZE_GB
#   check_model_exists MODEL_NAME
#
# Mocking strategy:
#   OLDINTELCLAW_CMD_DOWNLOAD — replaced with a script that creates a dummy file
#   OLDINTELCLAW_CMD_CHECKSUM — replaced with a script that outputs a known hash
#   OLDINTELCLAW_HOME         — pointed at a temp dir with a fresh manifest.json

load '../test_helper'

DOWNLOAD_SCRIPT="${SCRIPTS_DIR}/models/download.sh"

# Known hash value used by the mock checksum command
MOCK_HASH="abc123def456abc123def456abc123def456abc123def456abc123def456abc1"

setup() {
    # Temp home dir for all OldIntelClaw state
    export OLDINTELCLAW_HOME="$(mktemp -d /tmp/oldintelclaw_home_XXXXXX)"

    # Minimal valid manifest.json (empty models object)
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<'EOF'
{
  "models": {}
}
EOF

    # Mock download command: ignores the URL arg, creates a dummy file in the
    # output dir that was passed as the last argument.
    # The real curl invocation is: curl -L -C - --progress-bar <url> -o <file>
    # Our mock receives the same args; we just need to create something in the dir.
    _mock_download_ok="$(mktemp /tmp/mock_download_ok_XXXXXX)"
    cat > "${_mock_download_ok}" <<'MOCK'
#!/usr/bin/env bash
# Last argument after -o flag is the output path; create it.
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

    _mock_download_fail="$(mktemp /tmp/mock_download_fail_XXXXXX)"
    cat > "${_mock_download_fail}" <<'MOCK'
#!/usr/bin/env bash
echo "curl: download failed" >&2
exit 1
MOCK
    chmod +x "${_mock_download_fail}"
    export _MOCK_DOWNLOAD_FAIL="${_mock_download_fail}"

    # Mock checksum command: outputs the known hash for any file
    _mock_checksum_ok="$(mktemp /tmp/mock_checksum_ok_XXXXXX)"
    printf '#!/usr/bin/env bash\necho "%s  $1"\n' "${MOCK_HASH}" > "${_mock_checksum_ok}"
    chmod +x "${_mock_checksum_ok}"
    export _MOCK_CHECKSUM_OK="${_mock_checksum_ok}"

    # Default overrides (success path, no checksum)
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_OK} -o"
    export OLDINTELCLAW_CMD_CHECKSUM="${_MOCK_CHECKSUM_OK}"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${OLDINTELCLAW_HOME}" 2>/dev/null || true
    rm -f "${_MOCK_DOWNLOAD_OK}" "${_MOCK_DOWNLOAD_FAIL}" "${_MOCK_CHECKSUM_OK}" 2>/dev/null || true
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_CMD_DOWNLOAD
    unset OLDINTELCLAW_CMD_CHECKSUM
    unset OLDINTELCLAW_DRY_RUN
    unset _MOCK_DOWNLOAD_OK _MOCK_DOWNLOAD_FAIL _MOCK_CHECKSUM_OK
}

# ---------------------------------------------------------------------------
# Test 1: download_model succeeds (mock download creates file) → PASS, exits 0
# ---------------------------------------------------------------------------
@test "download_model with successful mock download — creates output dir, prints PASS, returns 0" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_OK} -o"

    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        download_model 'test-model' 'org/test-model' '${OLDINTELCLAW_HOME}/models/test-model'
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [ -d "${OLDINTELCLAW_HOME}/models/test-model" ]
}

# ---------------------------------------------------------------------------
# Test 2: download_model with mock download failing → FAIL, returns 1
# ---------------------------------------------------------------------------
@test "download_model with failing mock download — prints FAIL, returns 1" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        download_model 'test-model' 'org/test-model' '${OLDINTELCLAW_HOME}/models/test-model'
    "

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: download_model with correct checksum provided → PASS, returns 0
# ---------------------------------------------------------------------------
@test "download_model with matching checksum — prints PASS, returns 0" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_OK} -o"
    export OLDINTELCLAW_CMD_CHECKSUM="${_MOCK_CHECKSUM_OK}"

    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        download_model 'test-model' 'org/test-model' \
            '${OLDINTELCLAW_HOME}/models/test-model' \
            '${MOCK_HASH}'
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: download_model with checksum mismatch → FAIL, returns 1
# ---------------------------------------------------------------------------
@test "download_model with checksum mismatch — prints FAIL, returns 1" {
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_OK} -o"
    export OLDINTELCLAW_CMD_CHECKSUM="${_MOCK_CHECKSUM_OK}"

    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        download_model 'test-model' 'org/test-model' \
            '${OLDINTELCLAW_HOME}/models/test-model' \
            'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef'
    "

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: download_model when model already registered → SKIP, returns 0
# ---------------------------------------------------------------------------
@test "download_model when model already in manifest — prints SKIP, returns 0" {
    # Pre-register the model in manifest.json
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<EOF
{
  "models": {
    "already-registered": {
      "backend": "openvino",
      "path": "${OLDINTELCLAW_HOME}/models/already-registered",
      "size_gb": "1.5",
      "registered": "2026-01-01T00:00:00Z"
    }
  }
}
EOF

    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        download_model 'already-registered' 'org/already-registered' \
            '${OLDINTELCLAW_HOME}/models/already-registered'
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    # Download command must NOT have been called (no dummy file created anew)
}

# ---------------------------------------------------------------------------
# Test 6: register_model adds entry to manifest.json
# ---------------------------------------------------------------------------
@test "register_model adds model entry to manifest.json" {
    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        register_model 'phi-4-mini' 'openvino' \
            '${OLDINTELCLAW_HOME}/models/phi-4-mini' '3.8'
    "

    [ "$status" -eq 0 ]

    # Entry must be present in manifest.json
    grep -q '"phi-4-mini"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"openvino"' "${OLDINTELCLAW_HOME}/manifest.json"
    grep -q '"3.8"' "${OLDINTELCLAW_HOME}/manifest.json"
}

# ---------------------------------------------------------------------------
# Test 7: check_model_exists returns 0 for registered, 1 for unregistered
# ---------------------------------------------------------------------------
@test "check_model_exists returns 0 for registered model and 1 for unregistered model" {
    # Pre-register one model
    cat > "${OLDINTELCLAW_HOME}/manifest.json" <<'EOF'
{
  "models": {
    "known-model": {
      "backend": "openvino",
      "path": "/some/path",
      "size_gb": "2.0",
      "registered": "2026-01-01T00:00:00Z"
    }
  }
}
EOF

    # Registered model → exit 0
    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        check_model_exists 'known-model'
    "
    [ "$status" -eq 0 ]

    # Unregistered model → exit 1
    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        check_model_exists 'unknown-model'
    "
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Test 8: Dry run — prints plan, does not execute download
# ---------------------------------------------------------------------------
@test "Dry run mode — prints plan without executing download" {
    export OLDINTELCLAW_DRY_RUN="1"
    # Use the failing download so that if download runs at all, the test catches it
    export OLDINTELCLAW_CMD_DOWNLOAD="${_MOCK_DOWNLOAD_FAIL} -o"

    run bash -c "
        source '${DOWNLOAD_SCRIPT}'
        download_model 'test-model' 'org/test-model' \
            '${OLDINTELCLAW_HOME}/models/test-model'
    "

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" != *"FAIL"* ]]
}
