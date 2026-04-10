#!/usr/bin/env bats
# Unit tests for scripts/benchmark/performance.sh — Story 5.5: Performance Validation
#
# Uses env var overrides so tests never run real benchmarks or write to real paths.
#   OLDINTELCLAW_HOME            — temp dir acting as home
#   OLDINTELCLAW_BENCHMARK_LOG   — temp benchmark log path
#   OLDINTELCLAW_BENCH_TTFT_MS   — override TTFT measurement (ms)
#   OLDINTELCLAW_BENCH_TPS       — override TPS measurement (tokens/s)
#   OLDINTELCLAW_BENCH_COLD_START_MS — override cold start measurement (ms)
#   OLDINTELCLAW_BENCH_SWAP_KB   — override swap usage measurement (KB)
#   OLDINTELCLAW_DRY_RUN         — if "1", print plan and exit 0

load '../test_helper'

BENCHMARK_SCRIPT="${SCRIPTS_DIR}/benchmark/performance.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    mkdir -p "${OLDINTELCLAW_HOME}"
    export OLDINTELCLAW_BENCHMARK_LOG="${OLDINTELCLAW_HOME}/benchmark.log"

    # Default: all metrics meet targets
    # TTFT target: < 500ms
    export OLDINTELCLAW_BENCH_TTFT_MS="200"
    # TPS target: > 15 t/s
    export OLDINTELCLAW_BENCH_TPS="25"
    # Cold start target: < 10ms (WARN only)
    export OLDINTELCLAW_BENCH_COLD_START_MS="5"
    # Swap target: 0 KB
    export OLDINTELCLAW_BENCH_SWAP_KB="0"

    unset OLDINTELCLAW_DRY_RUN
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
    unset OLDINTELCLAW_HOME
    unset OLDINTELCLAW_BENCHMARK_LOG
    unset OLDINTELCLAW_BENCH_TTFT_MS
    unset OLDINTELCLAW_BENCH_TPS
    unset OLDINTELCLAW_BENCH_COLD_START_MS
    unset OLDINTELCLAW_BENCH_SWAP_KB
    unset OLDINTELCLAW_DRY_RUN
}

# ---------------------------------------------------------------------------
# Test 1: All metrics meet targets — all PASS, overall PASS, exits 0
# ---------------------------------------------------------------------------
@test "Benchmark: all metrics meet targets — all PASS and exits 0" {
    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" != *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: TTFT=600ms exceeds 500ms target — FAIL for TTFT
# ---------------------------------------------------------------------------
@test "Benchmark: TTFT=600ms exceeds target — FAIL for TTFT" {
    export OLDINTELCLAW_BENCH_TTFT_MS="600"

    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"TTFT"* ]] || [[ "$output" == *"ttft"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: TPS=10 below 15 t/s target — FAIL for TPS
# ---------------------------------------------------------------------------
@test "Benchmark: TPS=10 below target — FAIL for TPS" {
    export OLDINTELCLAW_BENCH_TPS="10"

    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"TPS"* ]] || [[ "$output" == *"tps"* ]] || [[ "$output" == *"token"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Cold start=15ms above 10ms target — WARN (not FAIL), exits 0
# ---------------------------------------------------------------------------
@test "Benchmark: cold start=15ms above target — WARN not FAIL, exits 0" {
    export OLDINTELCLAW_BENCH_COLD_START_MS="15"

    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
    # Must not produce a hard FAIL on cold start
    # (other metrics still pass so overall should not be exit 1)
}

# ---------------------------------------------------------------------------
# Test 5: Swap=1024 KB during inference — FAIL for swap
# ---------------------------------------------------------------------------
@test "Benchmark: swap=1024 KB — FAIL for swap usage" {
    export OLDINTELCLAW_BENCH_SWAP_KB="1024"

    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"swap"* ]] || [[ "$output" == *"SWAP"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: All metrics fail — overall FAIL, exits 1
# ---------------------------------------------------------------------------
@test "Benchmark: all metrics fail — overall FAIL and exits 1" {
    export OLDINTELCLAW_BENCH_TTFT_MS="600"
    export OLDINTELCLAW_BENCH_TPS="5"
    export OLDINTELCLAW_BENCH_COLD_START_MS="50"
    export OLDINTELCLAW_BENCH_SWAP_KB="2048"

    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: Benchmark log file written with results
# ---------------------------------------------------------------------------
@test "Benchmark: log file written with results after run" {
    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 0 ]
    [ -f "${OLDINTELCLAW_BENCHMARK_LOG}" ]
    log_content="$(cat "${OLDINTELCLAW_BENCHMARK_LOG}")"
    [[ "$log_content" == *"TTFT"* ]] || [[ "$log_content" == *"ttft"* ]] || [[ "$log_content" == *"PASS"* ]]
}

# ---------------------------------------------------------------------------
# Test 8: Dry run — prints plan, no measurements taken, no log written
# ---------------------------------------------------------------------------
@test "Benchmark: dry run prints plan and does not write log file, exits 0" {
    export OLDINTELCLAW_DRY_RUN="1"

    run "${BENCHMARK_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY"* ]] || [[ "$output" == *"dry"* ]]
    # Log file must not be written
    [ ! -f "${OLDINTELCLAW_BENCHMARK_LOG}" ]
}
