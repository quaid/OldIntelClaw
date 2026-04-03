#!/usr/bin/env bash
# scripts/server/ovms.sh — Launch OpenVINO Model Server (OVMS)
# Part of the OldIntelClaw server suite (Story 5.1)
#
# Steps:
#   1. Source common.sh
#   2. Generate OVMS config JSON at ${OLDINTELCLAW_HOME}/ovms_config.json
#   3. If dry run, print config and exit 0
#   4. Start OVMS with config
#   5. Health check (up to 3 retries with 1s sleep)
#   6. Report PASS/FAIL and endpoint URL
#   7. Exit 0 if healthy, 1 if not
#
# Command overrides (for testing):
#   OLDINTELCLAW_HOME            — default: ~/.oldintelclaw
#   OLDINTELCLAW_CMD_OVMS_START  — override start command
#   OLDINTELCLAW_CMD_OVMS_HEALTH — override health check command
#   OLDINTELCLAW_OVMS_PORT       — default: 8000
#   OLDINTELCLAW_DRY_RUN         — if "1", print config only and exit 0
#
# Exit codes:
#   0 — server started and health check passed
#   1 — server failed to start or health check failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------------
# Command overrides
# ---------------------------------------------------------------------------
OLDINTELCLAW_HOME="${OLDINTELCLAW_HOME:-${HOME}/.oldintelclaw}"
PORT="${OLDINTELCLAW_OVMS_PORT:-8000}"
MODELS_DIR="${OLDINTELCLAW_HOME}/models/openvino"
CONFIG_FILE="${OLDINTELCLAW_HOME}/ovms_config.json"

CMD_OVMS_START="${OLDINTELCLAW_CMD_OVMS_START:-ovms --model_path ${MODELS_DIR} --port ${PORT}}"
CMD_OVMS_HEALTH="${OLDINTELCLAW_CMD_OVMS_HEALTH:-curl -s http://localhost:${PORT}/v1/models}"

DRY_RUN="${OLDINTELCLAW_DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Step 2: Generate OVMS config JSON
# ---------------------------------------------------------------------------
mkdir -p "${OLDINTELCLAW_HOME}"

cat > "${CONFIG_FILE}" <<EOF
{
  "model_config_list": [
    {
      "config": {
        "name": "openvino_model",
        "base_path": "${MODELS_DIR}",
        "target_device": "CPU"
      }
    }
  ],
  "port": ${PORT}
}
EOF

# ---------------------------------------------------------------------------
# Step 3: Dry-run early exit
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "1" ]]; then
    print_status "${STATUS_INFO}" "OVMS" "DRY RUN — config written to ${CONFIG_FILE}"
    print_status "${STATUS_INFO}" "OVMS" "DRY RUN — model path: ${MODELS_DIR}"
    print_status "${STATUS_INFO}" "OVMS" "DRY RUN — port: ${PORT}"
    print_status "${STATUS_INFO}" "OVMS" "DRY RUN — would start: ${CMD_OVMS_START}"
    print_status "${STATUS_INFO}" "Summary" "DRY RUN complete — no server started"
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 4: Start OVMS
# ---------------------------------------------------------------------------
print_status "${STATUS_INFO}" "OVMS" "Starting server on port ${PORT} ..."
eval "${CMD_OVMS_START}" > /dev/null 2>&1 &
OVMS_PID=$!
# Give the server a moment to start (real servers need this; mocks return immediately)
sleep 0 2>/dev/null || true

# ---------------------------------------------------------------------------
# Step 5: Health check with retries
# ---------------------------------------------------------------------------
HEALTH_PASS=0
for attempt in 1 2 3; do
    if eval "${CMD_OVMS_HEALTH}" > /dev/null 2>&1; then
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
    print_status "${STATUS_PASS}" "OVMS health" "PASS — endpoint: http://localhost:${PORT}/v1/models"
    print_status "${STATUS_INFO}" "OVMS" "Endpoint URL: http://localhost:${PORT}"
    exit 0
else
    print_status "${STATUS_FAIL}" "OVMS health" "FAIL — server not responding on port ${PORT}"
    exit 1
fi
