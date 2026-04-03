#!/usr/bin/env bash
# scripts/config/zeroclaw_config.sh — Generate default config.toml for ZeroClaw
# Part of the OldIntelClaw install suite (Story 3.2)
#
# If a config.toml already exists it is backed up to config.toml.bak.<timestamp>
# before the new file is written. In dry-run mode the config is printed to
# stdout and no files are written or backed up.
#
# Overridable environment variables (for testing):
#   OLDINTELCLAW_HOME        — default: ~/.oldintelclaw
#   OLDINTELCLAW_CONFIG_FILE — default: ${OLDINTELCLAW_HOME}/config.toml
#   OLDINTELCLAW_DRY_RUN     — set to 1 to print config to stdout only
#
# Exit codes:
#   0 — config written (or printed in dry-run mode)
#   1 — write failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
CONFIG_FILE="${OLDINTELCLAW_CONFIG_FILE:-${OLDINTELCLAW_HOME}/config.toml}"
DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Config content
# ---------------------------------------------------------------------------
CONFIG_CONTENT='[provider]
type = "llamacpp"
base_url = "http://localhost:8000/v1"
default_model = "phi-4-mini"

[models.phi-4-mini]
backend = "openvino-igpu"
path = "models/openvino/phi-4-mini/"

[models.deepseek-r1-7b]
backend = "itrex-cpu"
path = "models/itrex/deepseek-r1-distill-qwen-7b/"

[models.gemma-3-4b]
backend = "openvino-igpu"
path = "models/openvino/gemma-3-4b/"

[models.qwen3-8b]
backend = "itrex-cpu"
path = "models/itrex/qwen3-8b-thinking/"

[models.smollm3-3b]
backend = "gguf-native"
path = "models/gguf/smollm3-3b/"'

# ---------------------------------------------------------------------------
# Dry run — print config to stdout and exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "zeroclaw-config" "DRY RUN — showing config that would be written to ${CONFIG_FILE}"
    printf '%s\n' "${CONFIG_CONTENT}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Backup existing config if present
# ---------------------------------------------------------------------------
if [[ -f "${CONFIG_FILE}" ]]; then
    TIMESTAMP="$(date +%s)"
    BACKUP_FILE="${CONFIG_FILE}.bak.${TIMESTAMP}"
    cp "${CONFIG_FILE}" "${BACKUP_FILE}"
    print_status "${STATUS_INFO}" "zeroclaw-config" "Backed up existing config to ${BACKUP_FILE}"
fi

# ---------------------------------------------------------------------------
# Ensure OLDINTELCLAW_HOME directory exists
# ---------------------------------------------------------------------------
mkdir -p "${OLDINTELCLAW_HOME}"

# ---------------------------------------------------------------------------
# Write config.toml
# ---------------------------------------------------------------------------
if printf '%s\n' "${CONFIG_CONTENT}" > "${CONFIG_FILE}"; then
    print_status "${STATUS_PASS}" "zeroclaw-config" "PASS — config.toml written to ${CONFIG_FILE}"
else
    print_status "${STATUS_FAIL}" "zeroclaw-config" "FAIL — could not write config to ${CONFIG_FILE}"
    exit 1
fi

exit 0
