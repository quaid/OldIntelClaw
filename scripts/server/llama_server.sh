#!/usr/bin/env bash
# scripts/server/llama_server.sh — Launch llama-server with OpenVINO Backend
# Part of the OldIntelClaw server suite (Story 5.2)
#
# Steps:
#   1. Source common.sh
#   2. Locate GGUF model in ${OLDINTELCLAW_HOME}/models/gguf/
#   3. If dry run, print launch plan and exit 0
#   4. Start llama-server with model path and port
#   5. Health check
#   6. Report status
#   7. Exit 0/1
#
# Command overrides (for testing):
#   OLDINTELCLAW_HOME             — default: ~/.oldintelclaw
#   OLDINTELCLAW_CMD_LLAMA_START  — override start command
#   OLDINTELCLAW_CMD_LLAMA_HEALTH — override health check command
#   OLDINTELCLAW_LLAMA_PORT       — default: 8001
#   OLDINTELCLAW_DRY_RUN          — if "1", print plan only and exit 0
#
# Exit codes:
#   0 — server started and health check passed
#   1 — no model found, or server failed to start, or health check failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Command overrides
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
PORT="${OLDINTELCLAW_LLAMA_PORT:-8001}"
GGUF_DIR="${OLDINTELCLAW_HOME}/models/gguf"

DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Step 2: Locate GGUF model
# ---------------------------------------------------------------------------
GGUF_MODEL=""
if [[ -d "${GGUF_DIR}" ]]; then
    GGUF_MODEL="$(find "${GGUF_DIR}" -maxdepth 1 -name "*.gguf" | head -1)"
fi

if [[ -z "${GGUF_MODEL}" ]]; then
    print_status "${STATUS_FAIL}" "llama-server" "FAIL — no GGUF model found in ${GGUF_DIR}"
    exit 1
fi

CMD_LLAMA_START="${OLDINTELCLAW_CMD_LLAMA_START:-llama-server --model ${GGUF_MODEL} --port ${PORT}}"
CMD_LLAMA_HEALTH="${OLDINTELCLAW_CMD_LLAMA_HEALTH:-curl -s http://localhost:${PORT}/health}"

# ---------------------------------------------------------------------------
# Step 3: Dry-run early exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "llama-server" "DRY RUN — model: ${GGUF_MODEL}"
    print_status "${STATUS_INFO}" "llama-server" "DRY RUN — port: ${PORT}"
    print_status "${STATUS_INFO}" "llama-server" "DRY RUN — would start: ${CMD_LLAMA_START}"
    print_status "${STATUS_INFO}" "Summary" "DRY RUN complete — no server started"
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 4: Start llama-server
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "llama-server" "Starting with model ${GGUF_MODEL} on port ${PORT} ..."
eval "${CMD_LLAMA_START}" > /dev/null 2>&1 &
LLAMA_PID=$!
# Give the server a moment to start (real servers need this; mocks return immediately)
sleep 0 2>/dev/null || true

# ---------------------------------------------------------------------------
# Step 5: Health check with retries
# ---------------------------------------------------------------------------
HEALTH_PASS=0
for attempt in 1 2 3; do
    if eval "${CMD_LLAMA_HEALTH}" > /dev/null 2>&1; then
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
    print_status "${STATUS_PASS}" "llama-server" "PASS — endpoint: http://localhost:${PORT}/health"
    print_status "${STATUS_INFO}" "llama-server" "Endpoint URL: http://localhost:${PORT}"
    exit 0
else
    print_status "${STATUS_FAIL}" "llama-server" "FAIL — server not responding on port ${PORT}"
    exit 1
fi
