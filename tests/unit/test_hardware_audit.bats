#!/usr/bin/env bats
# Unit tests for scripts/audit/hardware.sh
# Story 1.3: RAM and iGPU Availability Check

load '../test_helper'

# ---------------------------------------------------------------------------
# RAM tests
# ---------------------------------------------------------------------------

@test "16GB RAM: exits 0 and outputs PASS for RAM" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_16gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_iris_xe")"
    export OLDINTELCLAW_DRI_RENDER="${FIXTURES_DIR}/meminfo_16gb"  # any existing file

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"RAM"* ]]
}

@test "32GB RAM: exits 0 and outputs PASS for RAM" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_32gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_iris_xe")"
    export OLDINTELCLAW_DRI_RENDER="${FIXTURES_DIR}/meminfo_32gb"

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"RAM"* ]]
}

@test "12GB RAM: outputs WARN for RAM (below recommended)" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_12gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_iris_xe")"
    export OLDINTELCLAW_DRI_RENDER="${FIXTURES_DIR}/meminfo_12gb"

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"RAM"* ]]
}

@test "8GB RAM: exits 1 and outputs FAIL for RAM" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_8gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_iris_xe")"
    export OLDINTELCLAW_DRI_RENDER="${FIXTURES_DIR}/meminfo_8gb"

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"RAM"* ]]
}

# ---------------------------------------------------------------------------
# iGPU detection tests
# ---------------------------------------------------------------------------

@test "Iris Xe GPU in lspci: outputs PASS for iGPU" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_16gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_iris_xe")"
    export OLDINTELCLAW_DRI_RENDER="${FIXTURES_DIR}/meminfo_16gb"

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"iGPU"* ]]
}

@test "No Intel GPU in lspci: outputs FAIL for iGPU" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_16gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_no_intel_gpu")"
    export OLDINTELCLAW_DRI_RENDER="${FIXTURES_DIR}/meminfo_16gb"

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"iGPU"* ]]
}

# ---------------------------------------------------------------------------
# Render device tests
# ---------------------------------------------------------------------------

@test "Render device path exists: outputs PASS for render device" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_16gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_iris_xe")"
    # Point at any file we know exists as a stand-in for renderD128
    export OLDINTELCLAW_DRI_RENDER="${FIXTURES_DIR}/meminfo_16gb"

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"render"* ]]
}

@test "Render device path missing: outputs WARN for render device" {
    export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_16gb"
    export OLDINTELCLAW_LSPCI_OUTPUT="$(cat "${FIXTURES_DIR}/lspci_iris_xe")"
    export OLDINTELCLAW_DRI_RENDER="/dev/dri/renderD128_does_not_exist"

    run "${SCRIPTS_DIR}/audit/hardware.sh"

    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"render"* ]]
}
