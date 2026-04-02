#!/usr/bin/env bats
# Unit tests for scripts/audit/kernel_optimize.sh
# Story 1.6: Kernel Parameter Optimization

load '../test_helper'

KERNEL_OPT_SCRIPT="${SCRIPTS_DIR}/audit/kernel_optimize.sh"

setup() {
    # Create a fresh temp dir for each test to isolate file system state
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_MODPROBE_DIR="${TEST_TMPDIR}/modprobe.d"
    mkdir -p "${OLDINTELCLAW_MODPROBE_DIR}"

    # Mock dracut with a no-op by default; individual tests override as needed
    export OLDINTELCLAW_DRACUT_CMD="true"

    # Simulate running as root by default
    export OLDINTELCLAW_IS_ROOT="1"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# Root check
# ---------------------------------------------------------------------------

@test "Not root: exits 1 and prints error about needing root or sudo" {
    export OLDINTELCLAW_IS_ROOT="0"

    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"root"* ]] || [[ "$output" == *"sudo"* ]]
}

# ---------------------------------------------------------------------------
# Config file creation
# ---------------------------------------------------------------------------

@test "Root + no existing i915.conf: exits 0 and creates i915.conf" {
    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${OLDINTELCLAW_MODPROBE_DIR}/i915.conf" ]
}

@test "Root + no existing i915.conf: i915.conf contains correct kernel options" {
    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 0 ]
    grep -q "options i915 enable_guc=3 enable_fbc=1" "${OLDINTELCLAW_MODPROBE_DIR}/i915.conf"
}

# ---------------------------------------------------------------------------
# Backup of existing config
# ---------------------------------------------------------------------------

@test "Root + existing i915.conf: backs up existing file before writing new one" {
    # Pre-populate an existing config
    echo "options i915 enable_guc=0" > "${OLDINTELCLAW_MODPROBE_DIR}/i915.conf"

    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 0 ]
    # A backup file with .bak. in the name must exist
    local backup_count
    backup_count=$(find "${OLDINTELCLAW_MODPROBE_DIR}" -name "i915.conf.bak.*" | wc -l)
    [ "$backup_count" -ge 1 ]
}

@test "Root + existing i915.conf: backup contains original content" {
    local original_content="options i915 enable_guc=0 # old setting"
    echo "${original_content}" > "${OLDINTELCLAW_MODPROBE_DIR}/i915.conf"

    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 0 ]
    local backup_file
    backup_file="$(find "${OLDINTELCLAW_MODPROBE_DIR}" -name "i915.conf.bak.*" | head -1)"
    grep -q "${original_content}" "${backup_file}"
}

# ---------------------------------------------------------------------------
# Dracut / initramfs regeneration
# ---------------------------------------------------------------------------

@test "Dracut command is called: marker file is created by mock dracut" {
    local marker_file="${TEST_TMPDIR}/dracut_was_called"
    # Mock dracut writes a marker file so we can verify it ran
    export OLDINTELCLAW_DRACUT_CMD="touch ${marker_file}"

    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${marker_file}" ]
}

# ---------------------------------------------------------------------------
# Output messages
# ---------------------------------------------------------------------------

@test "Prints PASS status after writing config" {
    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

@test "Prints reboot warning message after completing" {
    run "${KERNEL_OPT_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"reboot"* ]] || [[ "$output" == *"Reboot"* ]] || [[ "$output" == *"REBOOT"* ]]
}
