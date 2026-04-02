#!/usr/bin/env bash
# Audit script: Fedora version validation
# Part of OldIntelClaw — Story 1.2
#
# Reads os-release from ${OLDINTELCLAW_OS_RELEASE:-/etc/os-release} and
# validates that the host is running a supported Fedora version.
#
# Exit codes:
#   0 — PASS (Fedora 42+) or WARN (Fedora 41)
#   1 — FAIL (wrong distro, unsupported version, or missing os-release)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

OS_RELEASE_FILE="${OLDINTELCLAW_OS_RELEASE:-/etc/os-release}"

COMPONENT="OS"
MIN_SUPPORTED=42
MIN_WARN=41

# Validate that the os-release file exists and is readable
if [[ ! -f "$OS_RELEASE_FILE" ]]; then
    print_status "$STATUS_FAIL" "$COMPONENT" \
        "os-release file not found: ${OS_RELEASE_FILE}"
    exit 1
fi

# Parse ID and VERSION_ID from the os-release file
os_id=""
os_version_id=""

while IFS='=' read -r key value; do
    # Strip surrounding quotes from value
    value="${value%\"}"
    value="${value#\"}"

    case "$key" in
        ID)         os_id="$value" ;;
        VERSION_ID) os_version_id="$value" ;;
    esac
done < "$OS_RELEASE_FILE"

# Require ID=fedora
if [[ "$os_id" != "fedora" ]]; then
    print_status "$STATUS_FAIL" "$COMPONENT" \
        "Unsupported OS: ${os_id} ${os_version_id} (Fedora required)"
    exit 1
fi

# Require a numeric VERSION_ID
if [[ -z "$os_version_id" ]] || ! [[ "$os_version_id" =~ ^[0-9]+$ ]]; then
    print_status "$STATUS_FAIL" "$COMPONENT" \
        "Could not determine Fedora version from os-release"
    exit 1
fi

version_num="$os_version_id"

if (( version_num >= MIN_SUPPORTED )); then
    print_status "$STATUS_PASS" "$COMPONENT" \
        "Fedora Linux ${version_num} (supported)"
    exit 0
elif (( version_num == MIN_WARN )); then
    print_status "$STATUS_WARN" "$COMPONENT" \
        "Fedora Linux ${version_num} (may work but not guaranteed; upgrade to 42+ recommended)"
    exit 0
else
    print_status "$STATUS_FAIL" "$COMPONENT" \
        "Fedora Linux ${version_num} (too old; Fedora 42+ required)"
    exit 1
fi
