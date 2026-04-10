#!/usr/bin/env bash
# State management library for OldIntelClaw setup
# Sourced by scripts/setup.sh
# Story 6.2: Structured Error Handling and Rollback

# Env var overrides (for testability)
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
OLDINTELCLAW_STATE_FILE="${OLDINTELCLAW_STATE_FILE:-${OLDINTELCLAW_HOME}/.setup-state.json}"

# ---------------------------------------------------------------------------
# _state_now — ISO-8601 timestamp for last_run
# ---------------------------------------------------------------------------
_state_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ---------------------------------------------------------------------------
# _state_write — write the in-memory state to the state file
#
# We carry state in the associative array _STATE_STEPS (step -> status).
# Because BATS sources this file into each test's shell, we use a simple
# approach: write JSON from the current shell variables.
# ---------------------------------------------------------------------------
_state_write() {
    local state_file="${OLDINTELCLAW_STATE_FILE}"
    local timestamp
    timestamp="$(_state_now)"

    # Build the steps JSON object
    local steps_json="{"
    local first=1
    for step in "${!_STATE_STEPS[@]}"; do
        if [[ "$first" -eq 0 ]]; then
            steps_json+=","
        fi
        steps_json+="\"${step}\":\"${_STATE_STEPS[$step]}\""
        first=0
    done
    steps_json+="}"

    printf '{\n  "version": 1,\n  "last_run": "%s",\n  "steps": %s\n}\n' \
        "${timestamp}" "${steps_json}" > "${state_file}"
}

# ---------------------------------------------------------------------------
# _state_load — read the state file into _STATE_STEPS
# ---------------------------------------------------------------------------
_state_load() {
    local state_file="${OLDINTELCLAW_STATE_FILE}"

    # Reset the in-memory map
    _STATE_STEPS=()

    [[ -f "${state_file}" ]] || return 0

    # Parse step entries from JSON using basic shell tools.
    # We handle only the flat "steps" object (no nested structures).
    local in_steps=0
    while IFS= read -r line; do
        # Detect entry into the steps block
        if [[ "$line" =~ '"steps"' ]]; then
            in_steps=1
            continue
        fi
        # Detect exit from steps block
        if [[ "$in_steps" -eq 1 && "$line" =~ ^\s*\} ]]; then
            in_steps=0
            continue
        fi
        # Parse "key": "value" pairs inside steps block
        if [[ "$in_steps" -eq 1 && "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            _STATE_STEPS["$key"]="$val"
        fi
    done < "${state_file}"
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# init_state — create or load the state file
# If the state file already exists, its contents are loaded into memory.
# If it does not exist, an empty state file is created.
init_state() {
    # Declare the associative array in the calling scope
    declare -gA _STATE_STEPS=()

    mkdir -p "$(dirname "${OLDINTELCLAW_STATE_FILE}")"

    if [[ -f "${OLDINTELCLAW_STATE_FILE}" ]]; then
        _state_load
    else
        _state_write
    fi
}

# mark_step STEP_NAME STATUS
# STATUS: "complete" | "failed" | "pending"
mark_step() {
    local step="$1"
    local status="$2"
    _STATE_STEPS["$step"]="$status"
    _state_write
}

# get_step_status STEP_NAME
# Prints the status of a step, or "pending" if not recorded.
get_step_status() {
    local step="$1"
    echo "${_STATE_STEPS[$step]:-pending}"
}

# should_skip STEP_NAME
# Returns 0 (true) if the step is already "complete" — caller should skip it.
# Returns 1 (false) if the step should be run.
should_skip() {
    local step="$1"
    local status
    status="$(get_step_status "$step")"
    [[ "$status" == "complete" ]]
}

# reset_state — clear all steps and rewrite an empty state file
reset_state() {
    declare -gA _STATE_STEPS=()
    _state_write
}
