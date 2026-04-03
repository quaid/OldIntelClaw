#!/usr/bin/env bats
# Unit tests for scripts/migrate/openclaw.sh — Story 3.4: OpenClaw SKILL.md Migration
#
# Fixture files in tests/fixtures/ cover basic, complex, empty, and malformed
# SKILL.md inputs. OLDINTELCLAW_HOME is pointed at a temp dir so no real
# filesystem state is altered.

load '../test_helper'

MIGRATE_SCRIPT="${SCRIPTS_DIR}/migrate/openclaw.sh"

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export OLDINTELCLAW_HOME="${TEST_TMPDIR}/oldintelclaw"
    export OLDINTELCLAW_MIGRATION_LOG="${OLDINTELCLAW_HOME}/migration.log"
    mkdir -p "${OLDINTELCLAW_HOME}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# Test 1: Basic SKILL.md — extracts agent name and description, writes TOML, exits 0
# ---------------------------------------------------------------------------
@test "Basic SKILL.md: extracts CodeHelper name and description, writes TOML, exits 0" {
    export OLDINTELCLAW_OPENCLAW_SKILL="${FIXTURES_DIR}/openclaw_skill_basic.md"

    run "${MIGRATE_SCRIPT}"

    [ "$status" -eq 0 ]

    # TOML output file must exist
    [ -f "${OLDINTELCLAW_HOME}/migrated_skills.toml" ]

    local toml_content
    toml_content="$(cat "${OLDINTELCLAW_HOME}/migrated_skills.toml")"

    # Must contain the agent name as a TOML section key
    [[ "$toml_content" == *"[skills.CodeHelper]"* ]]

    # Must contain the description field
    [[ "$toml_content" == *"description"* ]]
    [[ "$toml_content" == *"A coding assistant"* ]]

    # Must record source as migrated-from-openclaw
    [[ "$toml_content" == *"migrated-from-openclaw"* ]]

    # Must record original path
    [[ "$toml_content" == *"original_path"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: Complex SKILL.md — uses first heading as agent name, exits 0
# ---------------------------------------------------------------------------
@test "Complex SKILL.md: uses first heading as agent name, exits 0" {
    export OLDINTELCLAW_OPENCLAW_SKILL="${FIXTURES_DIR}/openclaw_skill_complex.md"

    run "${MIGRATE_SCRIPT}"

    [ "$status" -eq 0 ]

    [ -f "${OLDINTELCLAW_HOME}/migrated_skills.toml" ]

    local toml_content
    toml_content="$(cat "${OLDINTELCLAW_HOME}/migrated_skills.toml")"

    # First heading is "DataPipelineOrchestrator"
    [[ "$toml_content" == *"DataPipelineOrchestrator"* ]]
    [[ "$toml_content" == *"migrated-from-openclaw"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: Empty SKILL.md — logs warning, exits 0 (best-effort)
# ---------------------------------------------------------------------------
@test "Empty SKILL.md: logs warning, exits 0" {
    export OLDINTELCLAW_OPENCLAW_SKILL="${FIXTURES_DIR}/openclaw_skill_empty.md"

    run "${MIGRATE_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]] || [[ "$output" == *"warn"* ]] || [[ "$output" == *"warning"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: Malformed SKILL.md — logs warning, exits 0 (best-effort)
# ---------------------------------------------------------------------------
@test "Malformed SKILL.md: logs warning, exits 0" {
    export OLDINTELCLAW_OPENCLAW_SKILL="${FIXTURES_DIR}/openclaw_skill_malformed.md"

    run "${MIGRATE_SCRIPT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]] || [[ "$output" == *"warn"* ]] || [[ "$output" == *"warning"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: Original SKILL.md copied to backups/, not modified
# ---------------------------------------------------------------------------
@test "Original SKILL.md is copied to backups/ directory and not modified" {
    export OLDINTELCLAW_OPENCLAW_SKILL="${FIXTURES_DIR}/openclaw_skill_basic.md"

    # Record original content before migration
    local original_content
    original_content="$(cat "${FIXTURES_DIR}/openclaw_skill_basic.md")"

    run "${MIGRATE_SCRIPT}"

    [ "$status" -eq 0 ]

    # Backups directory must exist
    [ -d "${OLDINTELCLAW_HOME}/backups" ]

    # At least one file must exist in backups/
    local backup_count
    backup_count="$(ls "${OLDINTELCLAW_HOME}/backups/" | wc -l)"
    [ "${backup_count}" -ge 1 ]

    # Original fixture must be unchanged
    local after_content
    after_content="$(cat "${FIXTURES_DIR}/openclaw_skill_basic.md")"
    [ "${original_content}" = "${after_content}" ]
}

# ---------------------------------------------------------------------------
# Test 6: Migration log written with results
# ---------------------------------------------------------------------------
@test "Migration log is written after successful migration" {
    export OLDINTELCLAW_OPENCLAW_SKILL="${FIXTURES_DIR}/openclaw_skill_basic.md"

    run "${MIGRATE_SCRIPT}"

    [ "$status" -eq 0 ]

    # Migration log must exist and be non-empty
    [ -f "${OLDINTELCLAW_MIGRATION_LOG}" ]
    [ -s "${OLDINTELCLAW_MIGRATION_LOG}" ]
}

# ---------------------------------------------------------------------------
# Test 7: No SKILL.md provided (env var empty) — prints info, exits 0
# ---------------------------------------------------------------------------
@test "No SKILL.md provided: prints info message, exits 0" {
    export OLDINTELCLAW_OPENCLAW_SKILL=""

    run "${MIGRATE_SCRIPT}"

    [ "$status" -eq 0 ]
    # Must print some informational message about the missing path
    [[ "$output" == *"INFO"* ]] || [[ "$output" == *"info"* ]] || [[ "$output" == *"No"* ]] || [[ "$output" == *"no"* ]]
}
