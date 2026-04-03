#!/usr/bin/env bats
# Unit tests for scripts/install/intel_packages.sh — Story 2.1: Install Intel System Packages
#
# Uses env var overrides so tests never need real dnf/rpm.
#   OLDINTELCLAW_CMD_RPM_QUERY  — override rpm -q (return 0=installed, 1=missing)
#   OLDINTELCLAW_CMD_DNF_INSTALL — override sudo dnf install -y
#   OLDINTELCLAW_CMD_IS_ROOT    — override root check

load '../test_helper'

INTEL_PACKAGES_SCRIPT="${SCRIPTS_DIR}/install/intel_packages.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Returns 0 for every package (all installed)
all_installed_query() {
    return 0
}

# Returns 1 for every package (none installed)
none_installed_query() {
    return 1
}

setup() {
    # Default: simulate running as root
    export OLDINTELCLAW_CMD_IS_ROOT="true"
    # Default: no packages installed
    export OLDINTELCLAW_CMD_RPM_QUERY="false"
    # Default: install succeeds
    export OLDINTELCLAW_CMD_DNF_INSTALL="true"
    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    unset OLDINTELCLAW_CMD_IS_ROOT
    unset OLDINTELCLAW_CMD_RPM_QUERY
    unset OLDINTELCLAW_CMD_DNF_INSTALL
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: All packages already installed — all SKIP, exits 0
# ---------------------------------------------------------------------------
@test "All packages already installed — all SKIP and exits 0" {
    export OLDINTELCLAW_CMD_RPM_QUERY="true"

    run "${INTEL_PACKAGES_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    # No package should show INSTALLED (it was already there)
    [[ "$output" != *"INSTALLED"* ]]
    # All four packages should be mentioned
    [[ "$output" == *"intel-compute-runtime"* ]]
    [[ "$output" == *"intel-level-zero-gpu"* ]]
    [[ "$output" == *"level-zero"* ]]
    [[ "$output" == *"intel-media-driver"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: No packages installed, install succeeds — all INSTALLED, exits 0
# ---------------------------------------------------------------------------
@test "No packages installed and install succeeds — all INSTALLED and exits 0" {
    export OLDINTELCLAW_CMD_RPM_QUERY="false"
    export OLDINTELCLAW_CMD_DNF_INSTALL="true"

    run "${INTEL_PACKAGES_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALLED"* ]]
    [[ "$output" != *"FAIL"* ]]
    [[ "$output" == *"intel-compute-runtime"* ]]
    [[ "$output" == *"intel-level-zero-gpu"* ]]
    [[ "$output" == *"level-zero"* ]]
    [[ "$output" == *"intel-media-driver"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Partial install (2 present, 2 missing) — correct mix of SKIP/INSTALLED
# ---------------------------------------------------------------------------
@test "Partial install: 2 present show SKIP, 2 missing show INSTALLED after install" {
    # Use a wrapper script that returns 0 for the first two packages, 1 for the rest
    local query_script
    query_script="$(mktemp /tmp/rpm_query_partial_XXXXXX)"
    cat > "${query_script}" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    intel-compute-runtime) exit 0 ;;
    intel-level-zero-gpu)  exit 0 ;;
    *)                     exit 1 ;;
esac
EOF
    chmod +x "${query_script}"

    export OLDINTELCLAW_CMD_RPM_QUERY="${query_script}"
    export OLDINTELCLAW_CMD_DNF_INSTALL="true"

    run "${INTEL_PACKAGES_SCRIPT}"

    rm -f "${query_script}"

    [ "$status" -eq 0 ]

    # compute-runtime and level-zero-gpu were present → SKIP
    compute_line="$(echo "$output" | grep "intel-compute-runtime")"
    [[ "$compute_line" == *"SKIP"* ]]

    level_zero_gpu_line="$(echo "$output" | grep "intel-level-zero-gpu")"
    [[ "$level_zero_gpu_line" == *"SKIP"* ]]

    # level-zero and media-driver were missing → INSTALLED
    level_zero_line="$(echo "$output" | grep -E "^\[.*\] level-zero ")"
    [[ "$level_zero_line" == *"INSTALLED"* ]]

    media_line="$(echo "$output" | grep "intel-media-driver")"
    [[ "$media_line" == *"INSTALLED"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Install fails for one package — that one shows FAIL, exits 1
# ---------------------------------------------------------------------------
@test "Install fails for one package — shows FAIL and exits 1" {
    # Query: intel-media-driver is missing, others are installed
    local query_script
    query_script="$(mktemp /tmp/rpm_query_one_fail_XXXXXX)"
    cat > "${query_script}" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    intel-media-driver) exit 1 ;;
    *)                  exit 0 ;;
esac
EOF
    chmod +x "${query_script}"

    # Install always fails
    export OLDINTELCLAW_CMD_RPM_QUERY="${query_script}"
    export OLDINTELCLAW_CMD_DNF_INSTALL="false"

    run "${INTEL_PACKAGES_SCRIPT}"

    rm -f "${query_script}"

    [ "$status" -eq 1 ]
    media_line="$(echo "$output" | grep "intel-media-driver")"
    [[ "$media_line" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Dry run mode — prints plan, doesn't execute install
# ---------------------------------------------------------------------------
@test "Dry run mode — prints plan without executing install" {
    export OLDINTELCLAW_CMD_RPM_QUERY="false"
    export OLDINTELCLAW_DRY_RUN="1"
    # Set DNF to false so if it runs it would fail the test via exit code
    export OLDINTELCLAW_CMD_DNF_INSTALL="false"

    run "${INTEL_PACKAGES_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    # Should not show FAIL since install wasn't actually run
    [[ "$output" != *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: Not root — exits 1 with error message
# ---------------------------------------------------------------------------
@test "Not root — exits 1 with error message" {
    export OLDINTELCLAW_CMD_IS_ROOT="false"

    run "${INTEL_PACKAGES_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"root"* ]] || [[ "$output" == *"ROOT"* ]] || [[ "$output" == *"permission"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Summary line shows N/4 packages ready
# ---------------------------------------------------------------------------
@test "Summary line shows 4/4 packages ready when all installed" {
    export OLDINTELCLAW_CMD_RPM_QUERY="true"

    run "${INTEL_PACKAGES_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" =~ 4/4 ]]
}

@test "Summary line shows 0/4 when all fail to install" {
    export OLDINTELCLAW_CMD_RPM_QUERY="false"
    export OLDINTELCLAW_CMD_DNF_INSTALL="false"

    run "${INTEL_PACKAGES_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" =~ 0/4 ]]
}
