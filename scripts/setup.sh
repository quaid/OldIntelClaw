#!/usr/bin/env bash
# OldIntelClaw Setup — Main Entry Point
# Story 6.1: CLI Argument Parsing and Help System
#
# Usage: bash scripts/setup.sh [OPTIONS]

set -uo pipefail

# ---------------------------------------------------------------------------
# Env var overrides (for testability)
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
OLDINTELCLAW_STATE_FILE="${OLDINTELCLAW_STATE_FILE:-${OLDINTELCLAW_HOME}/.setup-state.json}"

# Sub-script hooks — override in tests with "true" to mock them out
OLDINTELCLAW_AUDIT_CMD="${OLDINTELCLAW_AUDIT_CMD:-}"
OLDINTELCLAW_INSTALL_CMD="${OLDINTELCLAW_INSTALL_CMD:-}"
OLDINTELCLAW_VERIFY_CMD="${OLDINTELCLAW_VERIFY_CMD:-}"

# ---------------------------------------------------------------------------
# Source the state management library (relative to this script)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
source "${SCRIPT_DIR}/lib/state.sh"

# ---------------------------------------------------------------------------
# Flags (set by argument parsing)
# ---------------------------------------------------------------------------
OPT_DRY_RUN=0
OPT_SKIP_MODELS=0
OPT_SKIP_KERNEL=0
OPT_VERBOSE=0
OPT_VERIFY_ONLY=0
OPT_RESET=0

# ---------------------------------------------------------------------------
# usage — print help text and exit
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: bash scripts/setup.sh [OPTIONS]

OldIntelClaw automated environment setup for 11th Gen Intel hardware.

Options:
  -h, --help         Print this help message and exit
      --dry-run      Show what would be done without making changes
      --skip-models  Skip model download and conversion steps
      --skip-kernel  Skip kernel parameter optimization
  -v, --verbose      Enable verbose output
      --verify-only  Run verification suite only; skip installation
      --reset        Clear saved setup state and start fresh

Exit codes:
  0  Success
  1  Failure
  2  Partial completion

Environment variable overrides:
  OLDINTELCLAW_HOME        Base directory (default: ~/.oldintelclaw)
  OLDINTELCLAW_DRY_RUN     Set to 1 to enable dry-run mode
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --dry-run)
                OPT_DRY_RUN=1
                export OLDINTELCLAW_DRY_RUN=1
                ;;
            --skip-models)
                OPT_SKIP_MODELS=1
                ;;
            --skip-kernel)
                OPT_SKIP_KERNEL=1
                ;;
            -v|--verbose)
                OPT_VERBOSE=1
                ;;
            --verify-only)
                OPT_VERIFY_ONLY=1
                ;;
            --reset)
                OPT_RESET=1
                ;;
            *)
                printf "Error: Unknown option: %s\n" "$1" >&2
                printf "Run with --help for usage information.\n" >&2
                exit 1
                ;;
        esac
        shift
    done
}

# ---------------------------------------------------------------------------
# step_header — print a progress header
# ---------------------------------------------------------------------------
step_header() {
    local n="$1"
    local total="$2"
    local desc="$3"
    printf "Step %s/%s: %s\n" "$n" "$total" "$desc"
}

# ---------------------------------------------------------------------------
# _run_cmd — execute a command or its override
# ---------------------------------------------------------------------------
_run_cmd() {
    local override="$1"
    shift
    if [[ -n "$override" ]]; then
        eval "$override"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# run_audit — execute the system audit phase
# ---------------------------------------------------------------------------
run_audit() {
    step_header 1 8 "System audit"
    _run_cmd "${OLDINTELCLAW_AUDIT_CMD}" "${SCRIPT_DIR}/audit/cpu.sh"
}

# ---------------------------------------------------------------------------
# run_install — execute the installation phase
# ---------------------------------------------------------------------------
run_install() {
    if [[ "$OPT_SKIP_MODELS" -eq 1 ]]; then
        printf "Skipping model download/conversion (--skip-models)\n"
    fi
    if [[ "$OPT_SKIP_KERNEL" -eq 1 ]]; then
        printf "Skipping kernel optimization (--skip-kernel)\n"
    fi
    step_header 2 8 "Package installation"
    _run_cmd "${OLDINTELCLAW_INSTALL_CMD}" true
}

# ---------------------------------------------------------------------------
# run_verify — execute the verification suite
# ---------------------------------------------------------------------------
run_verify() {
    step_header 8 8 "Verification"
    printf "Running verification suite...\n"
    _run_cmd "${OLDINTELCLAW_VERIFY_CMD}" true
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    # Initialise (or load) persistent state
    init_state

    # --reset: clear state and exit so the user can re-run cleanly
    if [[ "$OPT_RESET" -eq 1 ]]; then
        reset_state
        printf "State cleared. Re-run without --reset to begin setup.\n"
        exit 0
    fi

    # --dry-run: announce mode
    if [[ "$OPT_DRY_RUN" -eq 1 ]]; then
        printf "[dry-run] No changes will be made to the system.\n"
    fi

    # --verify-only: skip installation, jump to verification
    if [[ "$OPT_VERIFY_ONLY" -eq 1 ]]; then
        printf "Verify-only mode: skipping installation steps.\n"
        run_verify
        exit 0
    fi

    # Normal setup flow
    run_audit
    mark_step "audit" "complete"

    run_install
    mark_step "install" "complete"

    run_verify
    mark_step "verify" "complete"

    printf "Setup complete.\n"
    exit 0
}

main "$@"
