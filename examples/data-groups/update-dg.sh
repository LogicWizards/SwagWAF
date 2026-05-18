#!/usr/bin/env bash
# --------------------------------------------------------------------------
# SCRIPT: update-dg.sh
# --------------------------------------------------------------------------
# ABSTRACT: Create or replace the dg_injection_phrase data group on a BIG-IP
#     via the iControl REST API. Parses dg_injection_phrase.conf (the single
#     source of truth) and pushes it as a complete replacement (PUT) or
#     initial create (POST).
#
# USAGE:
#     ./update-dg.sh <bigip-host> <username>
#
#     The script prompts for your BIG-IP password — never pass it as an arg.
#     Run from the examples/data-groups/ directory, or set CONF_FILE below.
#
# REQUIREMENTS: curl, jq, python3
# --------------------------------------------------------------------------

set -euo pipefail

BIGIP="${1:?Usage: $0 <bigip-host> <username>}"
USER="${2:?Usage: $0 <bigip-host> <username>}"
DG_NAME="dg_injection_phrase"
PARTITION="Common"
ENDPOINT="https://${BIGIP}/mgmt/tm/ltm/data-group/internal/~${PARTITION}~${DG_NAME}"
CONF_FILE="$(dirname "$0")/dg_injection_phrase.conf"

[[ -f "${CONF_FILE}" ]] || { echo "ERROR: conf file not found: ${CONF_FILE}"; exit 1; }

# Prompt for password without echoing — never pass credentials as arguments
echo -n "BIG-IP password for ${USER}@${BIGIP}: "
read -rs BIGIP_PASS
echo

# --------------------------------------------------------------------------
# Parse dg_injection_phrase.conf (single source of truth) into a JSON records
# array. The conf format is:  "phrase" { data LEVEL }
# --------------------------------------------------------------------------
RECORDS=$(python3 - "${CONF_FILE}" <<'PYEOF'
import re, json, sys

with open(sys.argv[1]) as f:
    content = f.read()

records = []
for m in re.finditer(r'"([^"]+)"\s*\{\s*data\s+(\w+)\s*\}', content):
    records.append({"name": m.group(1), "data": m.group(2)})

if not records:
    print("ERROR: no records parsed from conf file", file=sys.stderr)
    sys.exit(1)

print(json.dumps(records))
PYEOF
)

PAYLOAD=$(jq -n \
  --arg name "${DG_NAME}" \
  --arg partition "${PARTITION}" \
  --argjson records "${RECORDS}" \
  '{name: $name, partition: $partition, type: "string", records: $records}')

# --------------------------------------------------------------------------
# Try PUT (update existing). Fall back to POST (create new) on 404.
# --------------------------------------------------------------------------
HTTP_STATUS=$(curl -sk -o /tmp/dg_response.json -w "%{http_code}" \
  -u "${USER}:${BIGIP_PASS}" \
  -X PUT "${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")

if [[ "${HTTP_STATUS}" == "404" ]]; then
  echo "Data group not found — creating it..."
  HTTP_STATUS=$(curl -sk -o /tmp/dg_response.json -w "%{http_code}" \
    -u "${USER}:${BIGIP_PASS}" \
    -X POST "https://${BIGIP}/mgmt/tm/ltm/data-group/internal" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}")
fi

if [[ "${HTTP_STATUS}" =~ ^2 ]]; then
  echo "OK (HTTP ${HTTP_STATUS}): ${DG_NAME} updated on ${BIGIP}"
else
  echo "ERROR (HTTP ${HTTP_STATUS}):"
  jq . /tmp/dg_response.json 2>/dev/null || cat /tmp/dg_response.json
  exit 1
fi
