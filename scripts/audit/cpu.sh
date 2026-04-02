#!/usr/bin/env bash
# scripts/audit/cpu.sh — Detect whether the CPU is 11th Gen+ Intel
# Part of the OldIntelClaw audit suite (Story 1.1)
#
# Exit codes: 0 = PASS (supported), 1 = FAIL (unsupported or undetectable)
# Respects OLDINTELCLAW_CPUINFO env var for testing; falls back to /proc/cpuinfo

set -euo pipefail

# Resolve the directory that contains this script so the source path is
# always correct regardless of the caller's working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

CPUINFO_PATH="${OLDINTELCLAW_CPUINFO:-/proc/cpuinfo}"

# ------------------------------------------------------------------
# Guard: cpuinfo must exist and be non-empty
# ------------------------------------------------------------------
if [[ ! -f "${CPUINFO_PATH}" ]] || [[ ! -s "${CPUINFO_PATH}" ]]; then
    print_status "${STATUS_FAIL}" "CPU" "Cannot read CPU info from ${CPUINFO_PATH}"
    exit 1
fi

# ------------------------------------------------------------------
# Extract the first "model name" line
# ------------------------------------------------------------------
model_name="$(grep -m1 '^model name' "${CPUINFO_PATH}" | cut -d: -f2- | sed 's/^[[:space:]]*//')"

if [[ -z "${model_name}" ]]; then
    print_status "${STATUS_FAIL}" "CPU" "No model name found in ${CPUINFO_PATH}"
    exit 1
fi

# ------------------------------------------------------------------
# Detection logic
#   Supported:  11th Gen, 12th Gen, 13th Gen, 14th Gen, Core Ultra
#   The model name must also be Intel (rules out AMD, ARM, etc.)
# ------------------------------------------------------------------
if echo "${model_name}" | grep -qiE '(11th|12th|13th|14th) Gen Intel|Intel.*Core Ultra'; then
    print_status "${STATUS_PASS}" "CPU" "${model_name}"
    exit 0
else
    print_status "${STATUS_FAIL}" "CPU" "Unsupported CPU: ${model_name}"
    exit 1
fi
