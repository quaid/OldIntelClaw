#!/usr/bin/env bash
# Logging and diagnostics library for OldIntelClaw
# Sourced by setup scripts — do not execute directly
# Story 6.3: Logging and Diagnostics Output

# ---------------------------------------------------------------------------
# Defaults (overridable via environment variables)
# ---------------------------------------------------------------------------

: "${OLDINTELCLAW_HOME:=${HOME}/.oldintelclaw}"
: "${OLDINTELCLAW_LOG_FILE:=${OLDINTELCLAW_HOME}/setup.log}"
: "${OLDINTELCLAW_VERBOSE:=}"
: "${OLDINTELCLAW_LOG_MAX_FILES:=5}"

# ---------------------------------------------------------------------------
# log_rotate — shift existing numbered log files down, delete beyond max
# ---------------------------------------------------------------------------
# Renames setup.log.N-1 -> setup.log.N (from highest down to 1),
# then renames setup.log -> setup.log.1.
# Files numbered beyond LOG_MAX_FILES are deleted.
# ---------------------------------------------------------------------------

log_rotate() {
    local log_file="${OLDINTELCLAW_LOG_FILE}"
    local max="${OLDINTELCLAW_LOG_MAX_FILES}"

    # Delete any rotated file at or beyond the max count
    local n=$(( max ))
    while [[ -f "${log_file}.${n}" ]]; do
        rm -f "${log_file}.${n}"
        n=$(( n + 1 ))
    done

    # Shift existing numbered files upward (N -> N+1), highest first
    local i
    for (( i = max - 1; i >= 1; i-- )); do
        if [[ -f "${log_file}.${i}" ]]; then
            mv "${log_file}.${i}" "${log_file}.$(( i + 1 ))"
        fi
    done

    # Rotate current log to .1
    if [[ -f "${log_file}" ]]; then
        mv "${log_file}" "${log_file}.1"
    fi
}

# ---------------------------------------------------------------------------
# log_init — create log directory, rotate old log, write header
# ---------------------------------------------------------------------------

log_init() {
    local log_file="${OLDINTELCLAW_LOG_FILE}"
    local log_dir
    log_dir="$(dirname "${log_file}")"

    # Ensure log directory exists
    mkdir -p "${log_dir}"

    # Rotate any existing log before starting fresh
    log_rotate

    # Write header to new log file
    {
        printf "=== OldIntelClaw setup log ===\n"
        printf "Started:  %s\n" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
        printf "Hostname: %s\n" "$(hostname)"
        printf "System:   %s\n" "$(uname -srm)"
        printf "==============================\n"
    } > "${log_file}"
}

# ---------------------------------------------------------------------------
# log_msg LEVEL MESSAGE — write a timestamped log entry
# ---------------------------------------------------------------------------
# LEVEL: INFO, WARN, ERROR, DEBUG
# DEBUG lines are suppressed unless OLDINTELCLAW_VERBOSE=1
# If OLDINTELCLAW_VERBOSE=1, all levels are also printed to stdout.
# ---------------------------------------------------------------------------

log_msg() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local log_file="${OLDINTELCLAW_LOG_FILE}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # DEBUG is suppressed entirely when VERBOSE is not set
    if [[ "${level}" == "DEBUG" && "${OLDINTELCLAW_VERBOSE}" != "1" ]]; then
        return 0
    fi

    local line="${timestamp} [${level}] ${message}"

    # Write to log file (only if it exists; guard against missing init)
    if [[ -f "${log_file}" ]]; then
        printf "%s\n" "${line}" >> "${log_file}"
    fi

    # Mirror to stdout when verbose mode is active
    if [[ "${OLDINTELCLAW_VERBOSE}" == "1" ]]; then
        printf "%s\n" "${line}"
    fi
}
