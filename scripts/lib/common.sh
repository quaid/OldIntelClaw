#!/usr/bin/env bash
# Common library for OldIntelClaw audit scripts
# Sourced by all scripts in scripts/audit/

set -euo pipefail

# Status codes
readonly STATUS_PASS="PASS"
readonly STATUS_WARN="WARN"
readonly STATUS_FAIL="FAIL"
readonly STATUS_INFO="INFO"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly RED='\033[0;31m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly GREEN=''
    readonly YELLOW=''
    readonly RED=''
    readonly BLUE=''
    readonly NC=''
fi

# Print a status result line
# Usage: print_status "PASS" "Component" "Detail message"
print_status() {
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

    printf "${color}[%4s]${NC} %-20s %s\n" "$status" "$component" "$message"
}
