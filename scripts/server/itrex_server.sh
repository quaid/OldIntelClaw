#!/usr/bin/env bash
# scripts/server/itrex_server.sh — Launch ITREX Inference Endpoint
# Part of the OldIntelClaw server suite (Story 5.3)
#
# Steps:
#   1. Source common.sh
#   2. Locate ITREX models in ${OLDINTELCLAW_HOME}/models/itrex/
#   3. If dry run, print launch plan and exit 0
#   4. Start ITREX server with model paths and port
#   5. Health check
#   6. Report status
#   7. Exit 0/1
#
# Command overrides (for testing):
#   OLDINTELCLAW_HOME              — default: ~/.oldintelclaw
#   OLDINTELCLAW_CMD_ITREX_START   — override start command
#   OLDINTELCLAW_CMD_ITREX_HEALTH  — override health check command
#   OLDINTELCLAW_ITREX_PORT        — default: 8002
#   OLDINTELCLAW_DRY_RUN           — if "1", print plan only and exit 0
#
# Exit codes:
#   0 — server started and health check passed
#   1 — no models found, or server failed to start, or health check failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Command overrides
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
PORT="${OLDINTELCLAW_ITREX_PORT:-8002}"
ITREX_DIR="${OLDINTELCLAW_HOME}/models/itrex"

DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Step 2: Locate ITREX models
# ---------------------------------------------------------------------------
ITREX_MODEL_COUNT=0
if [[ -d "${ITREX_DIR}" ]]; then
    ITREX_MODEL_COUNT="$(find "${ITREX_DIR}" -maxdepth 1 -type f | wc -l)"
fi

if [[ "${ITREX_MODEL_COUNT}" -eq 0 ]]; then
    print_status "${STATUS_FAIL}" "itrex-server" "FAIL — no ITREX models found in ${ITREX_DIR}"
    exit 1
fi

CMD_ITREX_START="${OLDINTELCLAW_CMD_ITREX_START:-python3 -m intel_extension_for_transformers.neural_chat.server --model_path ${ITREX_DIR} --port ${PORT}}"
CMD_ITREX_HEALTH="${OLDINTELCLAW_CMD_ITREX_HEALTH:-curl -s http://localhost:${PORT}/v1/models}"

# ---------------------------------------------------------------------------
# Step 3: Dry-run early exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "itrex-server" "DRY RUN — model path: ${ITREX_DIR}"
    print_status "${STATUS_INFO}" "itrex-server" "DRY RUN — models found: ${ITREX_MODEL_COUNT}"
    print_status "${STATUS_INFO}" "itrex-server" "DRY RUN — port: ${PORT}"
    print_status "${STATUS_INFO}" "itrex-server" "DRY RUN — would start: ${CMD_ITREX_START}"
    print_status "${STATUS_INFO}" "Summary" "DRY RUN complete — no server started"
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 4: Start ITREX server
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "itrex-server" "Starting with ${ITREX_MODEL_COUNT} model(s) on port ${PORT} ..."
eval "${CMD_ITREX_START}" > /dev/null 2>&1 &
ITREX_PID=$!
# Give the server a moment to start (real servers need this; mocks return immediately)
sleep 0 2>/dev/null || true

# ---------------------------------------------------------------------------
# Step 5: Health check with retries
# ---------------------------------------------------------------------------
HEALTH_PASS=0
for attempt in 1 2 3; do
    if eval "${CMD_ITREX_HEALTH}" > /dev/null 2>&1; then
        HEALTH_PASS=1
        break
    fi
    if [[ "${attempt}" -lt 3 ]]; then
        sleep 1
    fi
done

# ---------------------------------------------------------------------------
# Step 6: Report result
# ---------------------------------------------------------------------------
if [[ "${HEALTH_PASS}" -eq 1 ]]; then
    print_status "${STATUS_PASS}" "itrex-server" "PASS — endpoint: http://localhost:${PORT}/v1/models"
    print_status "${STATUS_INFO}" "itrex-server" "Endpoint URL: http://localhost:${PORT}"
    exit 0
else
    print_status "${STATUS_FAIL}" "itrex-server" "FAIL — server not responding on port ${PORT}"
    exit 1
fi
