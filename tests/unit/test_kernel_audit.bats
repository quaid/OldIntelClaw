#!/usr/bin/env bats
# Unit tests for scripts/audit/kernel.sh
# Story 1.5: Kernel Parameter Audit

load '../test_helper'

# ---------------------------------------------------------------------------
# Helper: run the kernel audit script with both sysfs env vars set
# ---------------------------------------------------------------------------
run_kernel_audit() {
    local guc_fixture="$1"
    local fbc_fixture="$2"
    export OLDINTELCLAW_SYSFS_GUC="$guc_fixture"
    export OLDINTELCLAW_SYSFS_FBC="$fbc_fixture"
    run "${SCRIPTS_DIR}/audit/kernel.sh"
}

# ---------------------------------------------------------------------------
# Test 1: Both parameters at optimal values (guc=3, fbc=1)
# Expected: exit 0, both lines show INFO "already optimal"
# ---------------------------------------------------------------------------

@test "both params optimal (guc=3, fbc=1): exits 0" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_optimal" \
                     "${FIXTURES_DIR}/sysfs_fbc_optimal"
    [ "$status" -eq 0 ]
}

@test "both params optimal (guc=3, fbc=1): guc shows INFO" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_optimal" \
                     "${FIXTURES_DIR}/sysfs_fbc_optimal"
    [[ "$output" == *"INFO"* ]]
    [[ "$output" == *"enable_guc"* ]]
    [[ "$output" == *"already optimal"* ]]
}

@test "both params optimal (guc=3, fbc=1): fbc shows INFO" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_optimal" \
                     "${FIXTURES_DIR}/sysfs_fbc_optimal"
    [[ "$output" == *"INFO"* ]]
    [[ "$output" == *"enable_fbc"* ]]
    [[ "$output" == *"already optimal"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Both parameters at default/suboptimal values (guc=0, fbc=-1)
# Expected: exit 0, both lines show WARN with recommendation
# ---------------------------------------------------------------------------

@test "both params default (guc=0, fbc=-1): exits 0" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_default" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [ "$status" -eq 0 ]
}

@test "both params default (guc=0, fbc=-1): guc shows WARN" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_default" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"enable_guc"* ]]
}

@test "both params default (guc=0, fbc=-1): guc WARN includes recommendation (enable_guc=3)" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_default" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [[ "$output" == *"enable_guc=3"* ]]
}

@test "both params default (guc=0, fbc=-1): fbc shows WARN" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_default" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"enable_fbc"* ]]
}

@test "both params default (guc=0, fbc=-1): fbc WARN includes recommendation (enable_fbc=1)" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_default" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [[ "$output" == *"enable_fbc=1"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: guc optimal, fbc suboptimal
# Expected: exit 0, guc shows INFO, fbc shows WARN
# ---------------------------------------------------------------------------

@test "guc optimal fbc suboptimal: exits 0" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_optimal" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [ "$status" -eq 0 ]
}

@test "guc optimal fbc suboptimal: guc shows INFO already optimal" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_optimal" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [[ "$output" == *"INFO"* ]]
    [[ "$output" == *"enable_guc"* ]]
    [[ "$output" == *"already optimal"* ]]
}

@test "guc optimal fbc suboptimal: fbc shows WARN with recommendation" {
    run_kernel_audit "${FIXTURES_DIR}/sysfs_guc_optimal" \
                     "${FIXTURES_DIR}/sysfs_fbc_default"
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"enable_fbc"* ]]
    [[ "$output" == *"enable_fbc=1"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Missing sysfs files (i915 module not loaded)
# Expected: exit 0, shows WARN about i915 module not loaded
# ---------------------------------------------------------------------------

@test "missing sysfs files: exits 0" {
    export OLDINTELCLAW_SYSFS_GUC="/tmp/oldintelclaw_nonexistent_guc_$$"
    export OLDINTELCLAW_SYSFS_FBC="/tmp/oldintelclaw_nonexistent_fbc_$$"
    run "${SCRIPTS_DIR}/audit/kernel.sh"
    [ "$status" -eq 0 ]
}

@test "missing sysfs files: shows WARN about i915 module not loaded" {
    export OLDINTELCLAW_SYSFS_GUC="/tmp/oldintelclaw_nonexistent_guc_$$"
    export OLDINTELCLAW_SYSFS_FBC="/tmp/oldintelclaw_nonexistent_fbc_$$"
    run "${SCRIPTS_DIR}/audit/kernel.sh"
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"i915"* ]]
    [[ "$output" == *"not loaded"* ]]
}
