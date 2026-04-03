#!/usr/bin/env bash
# scripts/verify/dependencies.sh — Post-install dependency verification suite
# Part of the OldIntelClaw verify suite (Story 2.6)
#
# Checks ALL dependencies installed by Epic 2 and produces a summary report.
#
# Each check command can be overridden via env vars for testing:
#   OLDINTELCLAW_CMD_OPENVINO        — default: python3 -c "import openvino"
#   OLDINTELCLAW_CMD_OPENVINO_GPU    — default: python3 -c "import openvino; ov=openvino.Core(); ov.get_property('GPU','FULL_DEVICE_NAME')"
#   OLDINTELCLAW_CMD_RUST            — default: rustc --version
#   OLDINTELCLAW_CMD_CARGO           — default: cargo --version
#   OLDINTELCLAW_CMD_PYTHON_VERSION  — default: python3 --version
#   OLDINTELCLAW_CMD_ITREX           — default: python3 -c "import intel_extension_for_transformers"
#   OLDINTELCLAW_CMD_ID_GROUPS       — default: id -Gn
#   OLDINTELCLAW_CMD_RPM_QUERY       — default: rpm -q
#   OLDINTELCLAW_DRI_RENDER          — default: /dev/dri/renderD128
#   OLDINTELCLAW_VERIFY_LOG          — default: ~/.oldintelclaw/verify.log
#
# Exit code: 0 if all checks pass, 1 if any check fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Command overrides
# ---------------------------------------------------------------------------
CMD_OPENVINO="${OLDINTELCLAW_CMD_OPENVINO:-python3 -c \"import openvino\"}"
CMD_OPENVINO_GPU="${OLDINTELCLAW_CMD_OPENVINO_GPU:-python3 -c \"import openvino; ov=openvino.Core(); ov.get_property('GPU','FULL_DEVICE_NAME')\"}"
CMD_RUST="${OLDINTELCLAW_CMD_RUST:-rustc --version}"
CMD_CARGO="${OLDINTELCLAW_CMD_CARGO:-cargo --version}"
CMD_PYTHON_VERSION="${OLDINTELCLAW_CMD_PYTHON_VERSION:-python3 --version}"
CMD_ITREX="${OLDINTELCLAW_CMD_ITREX:-python3 -c \"import intel_extension_for_transformers\"}"
CMD_ID_GROUPS="${OLDINTELCLAW_CMD_ID_GROUPS:-id -Gn}"
CMD_RPM_QUERY="${OLDINTELCLAW_CMD_RPM_QUERY:-rpm -q}"

DRI_RENDER="${OLDINTELCLAW_DRI_RENDER:-/dev/dri/renderD128}"

VERIFY_LOG="${OLDINTELCLAW_VERIFY_LOG:-${HOME}/.oldintelclaw/verify.log}"

# Minimum required Python version
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=12

# Intel packages required
INTEL_PACKAGES=(
    "intel-compute-runtime"
    "intel-level-zero-gpu"
    "level-zero"
    "intel-media-driver"
)

# ---------------------------------------------------------------------------
# Internal tracking
# ---------------------------------------------------------------------------
pass_count=0
fail_count=0
total_checks=0

# Capture all output lines for logging
declare -a output_lines=()

# ---------------------------------------------------------------------------
# emit LINE
#   Print a line to stdout and append to output_lines for later log writing.
# ---------------------------------------------------------------------------
emit() {
    local line="$1"
    printf "%s\n" "$line"
    output_lines+=("$line")
}

# ---------------------------------------------------------------------------
# emit_status STATUS COMPONENT MESSAGE
#   Like print_status but also routes output through emit.
# ---------------------------------------------------------------------------
emit_status() {
    local status="$1"
    local component="$2"
    local message="$3"

    local color
    case "$status" in
        OK|PASS) color="$GREEN" ;;
        WARN)    color="$YELLOW" ;;
        FAIL)    color="$RED" ;;
        INFO)    color="$BLUE" ;;
        *)       color="$NC" ;;
    esac

    local line
    line="$(printf "${color}[%4s]${NC} %-28s %s" "$status" "$component" "$message")"
    emit "$line"
}

# ---------------------------------------------------------------------------
# record_result STATUS
#   Increment pass or fail counter.
# ---------------------------------------------------------------------------
record_result() {
    local status="$1"
    (( total_checks++ )) || true
    if [[ "$status" == "OK" ]]; then
        (( pass_count++ )) || true
    else
        (( fail_count++ )) || true
    fi
}

# ---------------------------------------------------------------------------
# check_cmd COMPONENT CMD
#   Run CMD; emit OK or FAIL for COMPONENT.
# ---------------------------------------------------------------------------
check_cmd() {
    local component="$1"
    local cmd="$2"

    if eval "$cmd" > /dev/null 2>&1; then
        emit_status "OK" "$component" "OK"
        record_result "OK"
        return 0
    else
        emit_status "FAIL" "$component" "FAIL"
        record_result "FAIL"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# check_python_version
#   Parse Python version from CMD_PYTHON_VERSION output.
#   Requires >= PYTHON_MIN_MAJOR.PYTHON_MIN_MINOR.
# ---------------------------------------------------------------------------
check_python_version() {
    local version_output
    if ! version_output="$(eval "$CMD_PYTHON_VERSION" 2>&1)"; then
        emit_status "FAIL" "Python version" "FAIL — could not run python"
        record_result "FAIL"
        return 1
    fi

    local major minor
    if [[ "$version_output" =~ Python[[:space:]]+([0-9]+)\.([0-9]+) ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
    else
        emit_status "FAIL" "Python version" "FAIL — unrecognised: ${version_output}"
        record_result "FAIL"
        return 1
    fi

    if (( major > PYTHON_MIN_MAJOR )) || \
       (( major == PYTHON_MIN_MAJOR && minor >= PYTHON_MIN_MINOR )); then
        emit_status "OK" "Python version" "OK (${major}.${minor} >= ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR})"
        record_result "OK"
        return 0
    else
        emit_status "FAIL" "Python version" \
            "FAIL — ${major}.${minor} < ${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR} required"
        record_result "FAIL"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# check_intel_packages
#   Query each Intel RPM package via CMD_RPM_QUERY.
# ---------------------------------------------------------------------------
check_intel_packages() {
    for pkg in "${INTEL_PACKAGES[@]}"; do
        if eval "$CMD_RPM_QUERY" "$pkg" > /dev/null 2>&1; then
            emit_status "OK" "$pkg" "OK"
            record_result "OK"
        else
            emit_status "FAIL" "$pkg" "FAIL — not installed"
            record_result "FAIL"
        fi
    done
}

# ---------------------------------------------------------------------------
# check_groups
#   Verify current user belongs to video and render groups.
# ---------------------------------------------------------------------------
check_groups() {
    local groups_output
    groups_output="$(eval "$CMD_ID_GROUPS" 2>&1)"

    for grp in video render; do
        if echo " ${groups_output} " | grep -qw "$grp"; then
            emit_status "OK" "group:${grp}" "OK"
            record_result "OK"
        else
            emit_status "FAIL" "group:${grp}" "FAIL — not a member of ${grp}"
            record_result "FAIL"
        fi
    done
}

# ---------------------------------------------------------------------------
# check_render_device
#   Verify the render device node exists.
# ---------------------------------------------------------------------------
check_render_device() {
    if [[ -e "$DRI_RENDER" ]]; then
        emit_status "OK" "render device" "OK (${DRI_RENDER})"
        record_result "OK"
    else
        emit_status "FAIL" "render device" "FAIL — ${DRI_RENDER} not found"
        record_result "FAIL"
    fi
}

# ---------------------------------------------------------------------------
# write_log
#   Ensure log directory exists and write all captured output lines.
# ---------------------------------------------------------------------------
write_log() {
    local log_dir
    log_dir="$(dirname "$VERIFY_LOG")"
    mkdir -p "$log_dir"

    {
        printf "# OldIntelClaw dependency verification — %s\n" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        for line in "${output_lines[@]}"; do
            # Strip ANSI colour codes for the log file
            printf "%s\n" "$line" | sed 's/\x1b\[[0-9;]*m//g'
        done
    } > "$VERIFY_LOG"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

emit ""
emit "=== OldIntelClaw Dependency Verification ==="
emit ""

# 1. Intel packages (4 × rpm checks)
emit "--- Intel packages ---"
if check_intel_packages; then :; fi

emit ""

# 2. OpenVINO import
emit "--- OpenVINO ---"
if check_cmd "OpenVINO import" "${CMD_OPENVINO}"; then :; fi

# 3. OpenVINO GPU plugin
if check_cmd "OpenVINO GPU plugin" "${CMD_OPENVINO_GPU}"; then :; fi

emit ""

# 4. Rust toolchain
emit "--- Rust ---"
if check_cmd "rustc" "${CMD_RUST}"; then :; fi
if check_cmd "cargo" "${CMD_CARGO}"; then :; fi

emit ""

# 5. Python version
emit "--- Python ---"
if check_python_version; then :; fi

emit ""

# 6. ITREX
emit "--- ITREX ---"
if check_cmd "ITREX import" "${CMD_ITREX}"; then :; fi

emit ""

# 7. Group membership
emit "--- Group membership ---"
if check_groups; then :; fi

emit ""

# 8. Render device node
emit "--- Render device ---"
if check_render_device; then :; fi

emit ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
emit "============================================"
if [[ "$fail_count" -eq 0 ]]; then
    overall_status="PASS"
else
    overall_status="FAIL"
fi

emit_status "$overall_status" "Overall" "${pass_count}/${total_checks} checks passed"
emit "============================================"
emit ""

# Write report to log file
write_log

if [[ "$fail_count" -eq 0 ]]; then
    exit 0
else
    exit 1
fi
