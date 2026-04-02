#!/usr/bin/env bash
# Shared BATS test helper for OldIntelClaw
# Sourced via: load '../tests/test_helper'

# Project root — resolved from this helper file's location (tests/), one level up
# This works regardless of how deep the test file is nested.
export PROJECT_ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
export SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
export FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures"

# Override system paths so audit scripts read from fixtures instead of real system
# Each test sets these to point at fixture files
export OLDINTELCLAW_CPUINFO="${FIXTURES_DIR}/cpuinfo_default"
export OLDINTELCLAW_OS_RELEASE="${FIXTURES_DIR}/os_release_default"
export OLDINTELCLAW_MEMINFO="${FIXTURES_DIR}/meminfo_default"
export OLDINTELCLAW_LSPCI_OUTPUT=""
export OLDINTELCLAW_DRI_RENDER=""
