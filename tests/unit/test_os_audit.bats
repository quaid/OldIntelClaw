#!/usr/bin/env bats
# Unit tests for scripts/audit/os.sh — Story 1.2: Fedora Version Validation

load '../test_helper'

OS_AUDIT="${SCRIPTS_DIR}/audit/os.sh"

# ---------------------------------------------------------------------------
# Test 1: Fedora 42 — must PASS (primary supported version)
# ---------------------------------------------------------------------------
@test "Fedora 42 is detected as PASS" {
    export OLDINTELCLAW_OS_RELEASE="${FIXTURES_DIR}/os_release_fedora42"

    run "$OS_AUDIT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Fedora 43 — must PASS (future version, assumed compatible)
# ---------------------------------------------------------------------------
@test "Fedora 43 (future version) is detected as PASS" {
    export OLDINTELCLAW_OS_RELEASE="${FIXTURES_DIR}/os_release_fedora43"

    run "$OS_AUDIT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Fedora 41 — must exit 0 but print WARN (may work, not guaranteed)
# ---------------------------------------------------------------------------
@test "Fedora 41 (older version) exits 0 with WARN in output" {
    export OLDINTELCLAW_OS_RELEASE="${FIXTURES_DIR}/os_release_fedora41"

    run "$OS_AUDIT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Ubuntu 24.04 — must FAIL (wrong distro)
# ---------------------------------------------------------------------------
@test "Ubuntu 24.04 is rejected with FAIL and exit 1" {
    export OLDINTELCLAW_OS_RELEASE="${FIXTURES_DIR}/os_release_ubuntu"

    run "$OS_AUDIT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: RHEL 9 — must FAIL (ID=rhel, not fedora)
# ---------------------------------------------------------------------------
@test "RHEL 9 is rejected with FAIL and exit 1" {
    export OLDINTELCLAW_OS_RELEASE="${FIXTURES_DIR}/os_release_rhel9"

    run "$OS_AUDIT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: Missing / empty os-release — must FAIL with exit 1
# ---------------------------------------------------------------------------
@test "Missing os-release file exits 1 with FAIL in output" {
    export OLDINTELCLAW_OS_RELEASE="/nonexistent/path/os-release"

    run "$OS_AUDIT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}
