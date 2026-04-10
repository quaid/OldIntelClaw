#!/usr/bin/env bash
# Progress reporting library for OldIntelClaw
# Sourced by setup scripts — do not execute directly
# Story 6.4: Progress Reporting for Long Operations

# ---------------------------------------------------------------------------
# Defaults (overridable via environment variables)
# ---------------------------------------------------------------------------

# Auto-detect terminal if not explicitly set
if [[ -z "${OLDINTELCLAW_PROGRESS_ENABLED+x}" ]]; then
    if [[ -t 1 ]]; then
        OLDINTELCLAW_PROGRESS_ENABLED="1"
    else
        OLDINTELCLAW_PROGRESS_ENABLED="0"
    fi
fi

# PID of the background spinner process (empty when not running)
SPINNER_PID=""

# ---------------------------------------------------------------------------
# step_start STEP_NUM TOTAL DESCRIPTION — print step header
# ---------------------------------------------------------------------------

step_start() {
    local step_num="${1}"
    local total="${2}"
    local description="${3}"
    printf "[Step %s/%s] %s...\n" "${step_num}" "${total}" "${description}"
}

# ---------------------------------------------------------------------------
# step_done STEP_NUM TOTAL DESCRIPTION — print step completion
# ---------------------------------------------------------------------------
# Prints a checkmark when connected to a terminal, "done" otherwise.
# ---------------------------------------------------------------------------

step_done() {
    local step_num="${1}"
    local total="${2}"
    local description="${3}"

    local indicator
    if [[ -t 1 ]]; then
        indicator="✓"
    else
        indicator="done"
    fi

    printf "[Step %s/%s] %s %s\n" "${step_num}" "${total}" "${description}" "${indicator}"
}

# ---------------------------------------------------------------------------
# spinner_start MESSAGE — launch a background spinner process
# ---------------------------------------------------------------------------

spinner_start() {
    local message="${1:-Working}"

    # Only run spinner when progress is enabled
    if [[ "${OLDINTELCLAW_PROGRESS_ENABLED}" != "1" ]]; then
        return 0
    fi

    # Launch spinner in background; redirect output so it doesn't pollute tests
    (
        local chars=('|' '/' '-' '\\')
        local i=0
        while true; do
            printf "\r%s %s " "${message}" "${chars[$i]}" >&2
            i=$(( (i + 1) % 4 ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
}

# ---------------------------------------------------------------------------
# spinner_stop — kill the background spinner process
# ---------------------------------------------------------------------------

spinner_stop() {
    if [[ -n "${SPINNER_PID}" ]]; then
        kill "${SPINNER_PID}" 2>/dev/null || true
        wait "${SPINNER_PID}" 2>/dev/null || true
        SPINNER_PID=""
        # Clear the spinner line
        printf "\r\033[K" >&2 2>/dev/null || true
    fi
}
