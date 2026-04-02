#!/usr/bin/env bats
# Unit tests for scripts/audit/cpu.sh
# Story 1.1: CPU Generation Detection

load '../test_helper'

CPU_SCRIPT="${SCRIPTS_DIR}/audit/cpu.sh"

# ---------------------------------------------------------------------------
# PASS cases: supported Intel generations (11th Gen and above)
# ---------------------------------------------------------------------------

@test "11th Gen i7-1185G7 is detected as supported — exits 0 and outputs PASS" {
    export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_11th_gen"
    run "${CPU_SCRIPT}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

@test "12th Gen i7-1265U is detected as supported — exits 0 and outputs PASS" {
    export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_12th_gen"
    run "${CPU_SCRIPT}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

@test "13th Gen i7-13700H is detected as supported — exits 0 and outputs PASS" {
    export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_13th_gen"
    run "${CPU_SCRIPT}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# FAIL cases: unsupported or non-Intel CPUs
# ---------------------------------------------------------------------------

@test "10th Gen i7-10710U is rejected — exits 1 and outputs FAIL" {
    export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_10th_gen"
    run "${CPU_SCRIPT}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "AMD Ryzen 7 5800X is rejected — exits 1 and outputs FAIL" {
    export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_amd"
    run "${CPU_SCRIPT}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "Empty cpuinfo file is rejected — exits 1 and outputs FAIL" {
    export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_empty"
    run "${CPU_SCRIPT}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

@test "Missing cpuinfo file is rejected — exits 1 and outputs FAIL" {
    export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_does_not_exist"
    run "${CPU_SCRIPT}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}
