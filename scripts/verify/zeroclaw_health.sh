#!/usr/bin/env bash
# scripts/verify/zeroclaw_health.sh — ZeroClaw Health Check
# Part of the OldIntelClaw verify suite (Story 3.5)
#
# Verifies ZeroClaw is working, its config parses, memory usage is
# acceptable, and cold start is fast.
#
# Each check is a separate function using overridable env vars for testability.
#
# Env var overrides:
#   OLDINTELCLAW_CMD_ZEROCLAW_VERSION    — default: zeroclaw --version
#   OLDINTELCLAW_CMD_ZEROCLAW_CONFIG_CHECK — command to validate config
#                                           (default: zeroclaw config check)
#   OLDINTELCLAW_ZEROCLAW_RSS_KB         — pre-computed RSS in KB (skips live)
#   OLDINTELCLAW_ZEROCLAW_STARTUP_MS     — pre-computed startup time in ms (skips live)
#   OLDINTELCLAW_CONFIG_FILE             — default: ~/.oldintelclaw/config.toml
#   OLDINTELCLAW_HOME                    — default: ~/.oldintelclaw
#
# Exit codes:
#   0 — HEALTHY or DEGRADED (warns only, no failures)
#   1 — FAILED (at least one check failed)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
CMD_ZEROCLAW_VERSION="${OLDINTELCLAW_CMD_ZEROCLAW_VERSION:-zeroclaw --version}"
CMD_ZEROCLAW_CONFIG_CHECK="${OLDINTELCLAW_CMD_ZEROCLAW_CONFIG_CHECK:-zeroclaw config check}"
CONFIG_FILE="${OLDINTELCLAW_CONFIG_FILE:-${OLDINTELCLAW_HOME}/config.toml}"

# Thresholds
MEMORY_WARN_KB=5120   # 5 MB
STARTUP_WARN_MS=10    # 10 ms

# ---------------------------------------------------------------------------
# Internal tracking
# ---------------------------------------------------------------------------
fail_count=0
warn_count=0

# ---------------------------------------------------------------------------
# emit LINE
#   Print a line to stdout.
# ---------------------------------------------------------------------------
emit() {
    printf "%s\n" "$1"
}

# ---------------------------------------------------------------------------
# emit_status STATUS COMPONENT MESSAGE
#   Print a formatted status line.
# ---------------------------------------------------------------------------
emit_status() {
    local status="$1"
    local component="$2"
    local message="$3"

    local color
    case "$status" in
        PASS) color="$GREEN" ;;
        WARN) color="$YELLOW" ;;
        FAIL) color="$RED" ;;
        INFO) color="$BLUE" ;;
        *)    color="$NC" ;;
    esac

    printf "${color}[%4s]${NC} %-28s %s\n" "$status" "$component" "$message"
}

# ---------------------------------------------------------------------------
# check_binary
#   Verify the zeroclaw binary is present and executable.
#   Returns 0 on pass, 1 on fail.
# ---------------------------------------------------------------------------
check_binary() {
    if eval "$CMD_ZEROCLAW_VERSION" > /dev/null 2>&1; then
        emit_status "PASS" "zeroclaw binary" "OK"
        return 0
    else
        emit_status "FAIL" "zeroclaw binary" "FAIL — zeroclaw not found or not executable"
        (( fail_count++ )) || true
        return 1
    fi
}

# ---------------------------------------------------------------------------
# check_config
#   Verify config.toml exists and is parseable.
#   Returns 0 on pass, 1 on fail.
# ---------------------------------------------------------------------------
check_config() {
    # First check file existence
    if [[ ! -f "$CONFIG_FILE" ]]; then
        emit_status "FAIL" "config.toml" "FAIL — not found: ${CONFIG_FILE}"
        (( fail_count++ )) || true
        return 1
    fi

    # Then check parseability via the override command
    if eval "$CMD_ZEROCLAW_CONFIG_CHECK" > /dev/null 2>&1; then
        emit_status "PASS" "config.toml" "OK (${CONFIG_FILE})"
        return 0
    else
        emit_status "FAIL" "config.toml" "FAIL — config parse error"
        (( fail_count++ )) || true
        return 1
    fi
}

# ---------------------------------------------------------------------------
# check_memory
#   Verify idle RSS is below MEMORY_WARN_KB.
#   Uses OLDINTELCLAW_ZEROCLAW_RSS_KB override when set; otherwise measures live.
#   Issues WARN (not FAIL) when threshold exceeded.
# ---------------------------------------------------------------------------
check_memory() {
    local rss_kb

    if [[ -n "${OLDINTELCLAW_ZEROCLAW_RSS_KB:-}" ]]; then
        rss_kb="${OLDINTELCLAW_ZEROCLAW_RSS_KB}"
    else
        # Live measurement: start zeroclaw in background and read /proc/PID/status
        if ! command -v zeroclaw > /dev/null 2>&1; then
            emit_status "WARN" "memory (RSS)" "WARN — could not measure: zeroclaw not in PATH"
            (( warn_count++ )) || true
            return 0
        fi
        zeroclaw &>/dev/null &
        local zc_pid="$!"
        sleep 0.2  # brief pause to let process start
        rss_kb="$(awk '/^VmRSS:/ { print $2 }' "/proc/${zc_pid}/status" 2>/dev/null || echo 0)"
        kill "$zc_pid" 2>/dev/null || true
        wait "$zc_pid" 2>/dev/null || true
    fi

    if (( rss_kb < MEMORY_WARN_KB )); then
        emit_status "PASS" "memory (RSS)" "OK — ${rss_kb} KB < ${MEMORY_WARN_KB} KB"
        return 0
    else
        emit_status "WARN" "memory (RSS)" "WARN — ${rss_kb} KB >= ${MEMORY_WARN_KB} KB (limit: 5 MB)"
        (( warn_count++ )) || true
        return 0
    fi
}

# ---------------------------------------------------------------------------
# check_startup
#   Verify cold start time is below STARTUP_WARN_MS.
#   Uses OLDINTELCLAW_ZEROCLAW_STARTUP_MS override when set; otherwise measures live.
#   Issues WARN (not FAIL) when threshold exceeded.
# ---------------------------------------------------------------------------
check_startup() {
    local startup_ms

    if [[ -n "${OLDINTELCLAW_ZEROCLAW_STARTUP_MS:-}" ]]; then
        startup_ms="${OLDINTELCLAW_ZEROCLAW_STARTUP_MS}"
    else
        # Live measurement using bash millisecond timing
        if ! command -v zeroclaw > /dev/null 2>&1; then
            emit_status "WARN" "cold start" "WARN — could not measure: zeroclaw not in PATH"
            (( warn_count++ )) || true
            return 0
        fi
        local start_ms end_ms
        start_ms=$(( $(date +%s%3N) ))
        zeroclaw --version > /dev/null 2>&1 || true
        end_ms=$(( $(date +%s%3N) ))
        startup_ms=$(( end_ms - start_ms ))
    fi

    if (( startup_ms < STARTUP_WARN_MS )); then
        emit_status "PASS" "cold start" "OK — ${startup_ms} ms < ${STARTUP_WARN_MS} ms"
        return 0
    else
        emit_status "WARN" "cold start" "WARN — ${startup_ms} ms >= ${STARTUP_WARN_MS} ms (target: <10 ms)"
        (( warn_count++ )) || true
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

emit ""
emit "=== OldIntelClaw ZeroClaw Health Check ==="
emit ""

# 1. ZeroClaw binary
emit "--- Binary ---"
if check_binary; then :; fi

emit ""

# 2. Config file
emit "--- Configuration ---"
if check_config; then :; fi

emit ""

# 3. Memory usage
emit "--- Memory ---"
if check_memory; then :; fi

emit ""

# 4. Cold start time
emit "--- Startup ---"
if check_startup; then :; fi

emit ""

# ---------------------------------------------------------------------------
# Overall health report
# ---------------------------------------------------------------------------
emit "==========================================="

if (( fail_count > 0 )); then
    overall="FAILED"
elif (( warn_count > 0 )); then
    overall="DEGRADED"
else
    overall="HEALTHY"
fi

emit_status "$overall" "ZeroClaw health" "$(printf 'fails=%d warns=%d' "$fail_count" "$warn_count")"
emit "==========================================="
emit ""

if [[ "$overall" == "FAILED" ]]; then
    exit 1
else
    exit 0
fi
