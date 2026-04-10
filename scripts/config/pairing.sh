#!/usr/bin/env bash
# scripts/config/pairing.sh — ZeroClaw Gateway Pairing
# Part of the OldIntelClaw config suite (Story 5.4)
#
# Verifies each inference server endpoint is reachable, updates config.toml
# with all endpoint URLs and default model routing, then tests a ZeroClaw
# round-trip.
#
# Overridable environment variables (for testing):
#   OLDINTELCLAW_HOME              — default: ~/.oldintelclaw
#   OLDINTELCLAW_CONFIG_FILE       — default: ${OLDINTELCLAW_HOME}/config.toml
#   OLDINTELCLAW_CMD_OVMS_PING     — override OVMS health check
#                                    (default: curl -sf http://localhost:8000/v1/models)
#   OLDINTELCLAW_CMD_LLAMA_PING    — override llama-server health check
#                                    (default: curl -sf http://localhost:8001/health)
#   OLDINTELCLAW_CMD_ITREX_PING    — override ITREX health check
#                                    (default: curl -sf http://localhost:8002/v1/models)
#   OLDINTELCLAW_CMD_ZEROCLAW_PING — override ZeroClaw round-trip test
#   OLDINTELCLAW_DRY_RUN           — set to 1 to print plan to stdout only
#
# Exit codes:
#   0 — all endpoints paired successfully
#   1 — one or more endpoints unreachable

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

CMD_OVMS_PING="${OLDINTELCLAW_CMD_OVMS_PING:-curl -sf http://localhost:8000/v1/models}"
CMD_LLAMA_PING="${OLDINTELCLAW_CMD_LLAMA_PING:-curl -sf http://localhost:8001/health}"
CMD_ITREX_PING="${OLDINTELCLAW_CMD_ITREX_PING:-curl -sf http://localhost:8002/v1/models}"
CMD_ZEROCLAW_PING="${OLDINTELCLAW_CMD_ZEROCLAW_PING:-zeroclaw ping}"

OVMS_URL="http://localhost:8000/v1"
LLAMA_URL="http://localhost:8001/v1"
ITREX_URL="http://localhost:8002/v1"

# ---------------------------------------------------------------------------
# Internal tracking
# ---------------------------------------------------------------------------
fail_count=0

# ---------------------------------------------------------------------------
# Dry run — print plan and exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "pairing" "DRY RUN — would pair endpoints:"
    printf '  OVMS:        %s\n' "${OVMS_URL}"
    printf '  llama-server: %s\n' "${LLAMA_URL}"
    printf '  ITREX:       %s\n' "${ITREX_URL}"
    printf '  Routing: general->phi-4-mini, reasoning->deepseek-r1-7b, background->smollm3-3b\n'
    exit 0
fi

# ---------------------------------------------------------------------------
# Ensure config directory exists
# ---------------------------------------------------------------------------
mkdir -p "${OLDINTELCLAW_HOME}"

# ---------------------------------------------------------------------------
# ping_endpoint LABEL CMD URL
#   Ping a server endpoint and report status.
#   Increments fail_count on failure.
# ---------------------------------------------------------------------------
ping_endpoint() {
    local label="$1"
    local cmd="$2"
    local url="$3"

    if eval "${cmd}" > /dev/null 2>&1; then
        print_status "${STATUS_PASS}" "${label}" "PASS — reachable at ${url}"
        return 0
    else
        print_status "${STATUS_FAIL}" "${label}" "FAIL — ${url} unreachable"
        (( fail_count++ )) || true
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main — verify endpoints
# ---------------------------------------------------------------------------
printf '\n'
printf '=== OldIntelClaw ZeroClaw Gateway Pairing ===\n'
printf '\n'

printf '%s\n' "--- Endpoint Checks ---"
ping_endpoint "ovms"         "${CMD_OVMS_PING}"   "${OVMS_URL}"
ping_endpoint "llama-server" "${CMD_LLAMA_PING}"  "${LLAMA_URL}"
ping_endpoint "itrex"        "${CMD_ITREX_PING}"  "${ITREX_URL}"

# ---------------------------------------------------------------------------
# Update config.toml with endpoint URLs and default routing
# ---------------------------------------------------------------------------
printf '\n'
printf '%s\n' "--- Updating config.toml ---"

CONFIG_CONTENT="[endpoints]
ovms_url = \"${OVMS_URL}\"
llama_url = \"${LLAMA_URL}\"
itrex_url = \"${ITREX_URL}\"

[routing]
general = \"phi-4-mini\"
reasoning = \"deepseek-r1-7b\"
background = \"smollm3-3b\"

[models.phi-4-mini]
backend = \"openvino-igpu\"
endpoint = \"ovms\"

[models.deepseek-r1-7b]
backend = \"itrex-cpu\"
endpoint = \"itrex\"

[models.smollm3-3b]
backend = \"gguf-native\"
endpoint = \"llama\"
"

if printf '%s\n' "${CONFIG_CONTENT}" > "${CONFIG_FILE}"; then
    print_status "${STATUS_PASS}" "config.toml" "PASS — endpoints and routing written to ${CONFIG_FILE}"
else
    print_status "${STATUS_FAIL}" "config.toml" "FAIL — could not write ${CONFIG_FILE}"
    (( fail_count++ )) || true
fi

# ---------------------------------------------------------------------------
# ZeroClaw round-trip test
# ---------------------------------------------------------------------------
printf '\n'
printf '%s\n' "--- ZeroClaw Round-Trip ---"

if eval "${CMD_ZEROCLAW_PING}" > /dev/null 2>&1; then
    print_status "${STATUS_PASS}" "zeroclaw-roundtrip" "PASS — ZeroClaw gateway responded"
else
    print_status "${STATUS_FAIL}" "zeroclaw-roundtrip" "FAIL — ZeroClaw round-trip failed"
    (( fail_count++ )) || true
fi

# ---------------------------------------------------------------------------
# Overall status
# ---------------------------------------------------------------------------
printf '\n'
printf '=============================================\n'

if (( fail_count > 0 )); then
    print_status "${STATUS_FAIL}" "pairing" "FAIL — ${fail_count} endpoint(s) unreachable"
    printf '=============================================\n'
    exit 1
else
    print_status "${STATUS_PASS}" "pairing" "PASS — all endpoints paired"
    printf '=============================================\n'
    exit 0
fi
