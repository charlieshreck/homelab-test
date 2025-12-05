#!/bin/bash
set -e

# Use v1.7.5 as a stable default, but allow overriding via an environment variable.
TALOS_VERSION="${TALOS_VERSION:-v1.11.3}"
SCHEMATIC_ID="${SCHEMATIC_ID:-}"

# Only generate a new schematic ID if one isn't already provided.
if [ -z "$SCHEMATIC_ID" ]; then
    # Post a customization schematic to the Talos Factory API.
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
#      - siderolabs/nfs-client       

SCHEMATIC
)
    
    # Extract the schematic ID from the JSON response.
    SCHEMATIC_ID=$(echo "$SCHEMATIC_RESPONSE" | jq -r '.id')
    
    # Provide a known-good fallback Schematic ID if the API call fails.
    if [ -z "$SCHEMATIC_ID" ] || [ "$SCHEMATIC_ID" == "null" ]; then
        # This is the ID for the extensions listed above on Talos v1.7.5
        SCHEMATIC_ID="ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
    fi
fi

# Output the final JSON for Terraform to consume.
cat <<JSON
{
  "version": "$TALOS_VERSION",
  "schematic_id": "$SCHEMATIC_ID"
}
JSON

