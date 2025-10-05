#!/bin/bash
set -e

TALOS_VERSION="${TALOS_VERSION:-v1.11.2}"
SCHEMATIC_ID="${SCHEMATIC_ID:-}"

if [ -z "$SCHEMATIC_ID" ]; then
    SCHEMATIC_RESPONSE=$(curl -s -X POST \
        --data-binary @- \
        https://factory.talos.dev/schematics <<SCHEMATIC
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/intel-ucode
      - siderolabs/i915-ucode
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
SCHEMATIC
)
    
    SCHEMATIC_ID=$(echo "$SCHEMATIC_RESPONSE" | jq -r '.id')
    
    if [ -z "$SCHEMATIC_ID" ] || [ "$SCHEMATIC_ID" == "null" ]; then
        SCHEMATIC_ID="ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
    fi
fi

cat <<JSON
{
  "version": "$TALOS_VERSION",
  "schematic_id": "$SCHEMATIC_ID"
}
JSON
