#!/usr/bin/env bash
# scripts/migrate/openclaw.sh — Migrate an OpenClaw SKILL.md to ZeroClaw format
# Part of the OldIntelClaw migration suite (Story 3.4)
#
# Reads an OpenClaw SKILL.md file, extracts agent name and description,
# generates a ZeroClaw-compatible TOML snippet, backs up the original,
# and writes a migration log entry.
#
# Overridable environment variables:
#   OLDINTELCLAW_OPENCLAW_SKILL  — path to the SKILL.md to migrate (required)
#   OLDINTELCLAW_HOME            — default: ~/.oldintelclaw
#   OLDINTELCLAW_MIGRATION_LOG   — default: ${OLDINTELCLAW_HOME}/migration.log
#
# Exit code: always 0 — best-effort migration, never fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
MIGRATION_LOG="${OLDINTELCLAW_MIGRATION_LOG:-${OLDINTELCLAW_HOME}/migration.log}"
SKILL_PATH="${OLDINTELCLAW_OPENCLAW_SKILL:-}"

TOML_OUTPUT="${OLDINTELCLAW_HOME}/migrated_skills.toml"
BACKUP_DIR="${OLDINTELCLAW_HOME}/backups"

# ---------------------------------------------------------------------------
# Ensure output directories exist
# ---------------------------------------------------------------------------
mkdir -p "${OLDINTELCLAW_HOME}" "${BACKUP_DIR}"

# ---------------------------------------------------------------------------
# Guard: no SKILL.md path provided
# ---------------------------------------------------------------------------
if [[ -z "${SKILL_PATH}" ]]; then
    print_status "${STATUS_INFO}" "openclaw-migrate" "No SKILL.md path provided — nothing to migrate"
    printf '%s [INFO] No SKILL.md path provided — skipped\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "${MIGRATION_LOG}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Guard: SKILL.md file does not exist
# ---------------------------------------------------------------------------
if [[ ! -f "${SKILL_PATH}" ]]; then
    print_status "${STATUS_WARN}" "openclaw-migrate" "WARN — SKILL.md not found: ${SKILL_PATH}"
    printf '%s [WARN] SKILL.md not found: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${SKILL_PATH}" >> "${MIGRATION_LOG}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Read and parse SKILL.md
# ---------------------------------------------------------------------------
skill_content="$(cat "${SKILL_PATH}")"

# Guard: empty file
if [[ -z "${skill_content}" ]]; then
    print_status "${STATUS_WARN}" "openclaw-migrate" "WARN — SKILL.md is empty: ${SKILL_PATH}"
    printf '%s [WARN] SKILL.md is empty: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${SKILL_PATH}" >> "${MIGRATION_LOG}"
    exit 0
fi

# Extract agent name:
#   Priority 1 — "# Agent: <name>" line
#   Priority 2 — first "# <Heading>" line
agent_name=""

# Try "# Agent: <name>" first
if [[ "${skill_content}" =~ ^#[[:space:]]+Agent:[[:space:]]+([^$'\n']+) ]]; then
    agent_name="${BASH_REMATCH[1]}"
    agent_name="${agent_name%%$'\r'}"   # strip trailing CR if present
else
    # Try first level-1 heading
    while IFS= read -r line; do
        if [[ "${line}" =~ ^#[[:space:]]+(.+)$ ]]; then
            agent_name="${BASH_REMATCH[1]}"
            agent_name="${agent_name%%$'\r'}"
            break
        fi
    done <<< "${skill_content}"
fi

# Guard: no name extractable
if [[ -z "${agent_name}" ]]; then
    print_status "${STATUS_WARN}" "openclaw-migrate" "WARN — could not extract agent name from: ${SKILL_PATH}"
    printf '%s [WARN] Could not extract agent name: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${SKILL_PATH}" >> "${MIGRATION_LOG}"
    exit 0
fi

# Sanitise agent_name for use as a TOML key: replace spaces/special chars with underscores
toml_key="${agent_name//[^A-Za-z0-9_-]/_}"

# Extract description:
#   Priority 1 — "Description: <text>" line
#   Priority 2 — first non-empty, non-heading paragraph line
description=""

while IFS= read -r line; do
    if [[ "${line}" =~ ^Description:[[:space:]]*(.+)$ ]]; then
        description="${BASH_REMATCH[1]}"
        description="${description%%$'\r'}"
        break
    fi
done <<< "${skill_content}"

if [[ -z "${description}" ]]; then
    # Fallback: first non-empty, non-heading line
    while IFS= read -r line; do
        line="${line%%$'\r'}"
        if [[ -n "${line}" && "${line}" != \#* ]]; then
            description="${line}"
            break
        fi
    done <<< "${skill_content}"
fi

# If still empty, use a placeholder
if [[ -z "${description}" ]]; then
    description="(no description extracted)"
fi

# ---------------------------------------------------------------------------
# Write TOML snippet
# ---------------------------------------------------------------------------
{
    printf '[skills.%s]\n' "${toml_key}"
    printf 'description = "%s"\n' "${description}"
    printf 'source = "migrated-from-openclaw"\n'
    printf 'original_path = "%s"\n' "${SKILL_PATH}"
    printf '\n'
} >> "${TOML_OUTPUT}"

print_status "${STATUS_PASS}" "openclaw-migrate" "TOML snippet written for agent: ${agent_name}"

# ---------------------------------------------------------------------------
# Back up original SKILL.md
# ---------------------------------------------------------------------------
backup_filename="$(basename "${SKILL_PATH}").$(date -u '+%Y%m%dT%H%M%SZ').bak"
cp "${SKILL_PATH}" "${BACKUP_DIR}/${backup_filename}"

print_status "${STATUS_INFO}" "openclaw-migrate" "Backup saved: ${BACKUP_DIR}/${backup_filename}"

# ---------------------------------------------------------------------------
# Write migration log entry
# ---------------------------------------------------------------------------
{
    printf '%s [INFO] Migrated: %s -> agent=%s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${SKILL_PATH}" "${agent_name}"
    printf '%s [INFO] TOML written: %s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${TOML_OUTPUT}"
    printf '%s [INFO] Backup: %s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${BACKUP_DIR}/${backup_filename}"
} >> "${MIGRATION_LOG}"

exit 0
