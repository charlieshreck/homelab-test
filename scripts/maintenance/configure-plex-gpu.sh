#!/bin/bash
# Configure AMD 680M GPU passthrough for Plex LXC container
# Run on Proxmox host: ./configure-plex-gpu.sh <CONTAINER_ID>

set -euo pipefail

CTID="${1:?Container ID required}"
LXC_CONF="/etc/pve/lxc/${CTID}.conf"

echo "Configuring GPU passthrough for container ${CTID}..."

# Verify GPU exists
if [[ ! -e /dev/dri/renderD128 ]]; then
    echo "ERROR: /dev/dri/renderD128 not found. Is AMD GPU driver loaded?"
    exit 1
fi

# Get render device GID (usually 'render' group = 104 or 106)
RENDER_GID=$(stat -c '%g' /dev/dri/renderD128)
echo "Render device GID: ${RENDER_GID}"

# Stop container if running
if pct status ${CTID} | grep -q running; then
    echo "Stopping container..."
    pct stop ${CTID}
    sleep 5
fi

# Backup existing config
cp "${LXC_CONF}" "${LXC_CONF}.bak.$(date +%Y%m%d%H%M%S)"

# Remove existing GPU config if present
sed -i '/^dev[0-9]*:/d' "${LXC_CONF}"
sed -i '/^lxc.cgroup2.devices.allow.*226/d' "${LXC_CONF}"
sed -i '/^lxc.mount.entry.*dri/d' "${LXC_CONF}"

# Add GPU passthrough configuration
cat >> "${LXC_CONF}" << EOF

# AMD 680M GPU Passthrough for VAAPI transcoding
dev0: /dev/dri/card0,gid=${RENDER_GID},mode=0666
dev1: /dev/dri/renderD128,gid=${RENDER_GID},mode=0666

# cgroup device access
lxc.cgroup2.devices.allow: c 226:* rwm

# Mount DRI devices
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
EOF

echo "GPU configuration added to ${LXC_CONF}"

# Start container
echo "Starting container..."
pct start ${CTID}

# Wait for container to be ready
sleep 10

# Verify GPU is accessible inside container
echo "Verifying GPU access inside container..."
pct exec ${CTID} -- ls -la /dev/dri/

echo "GPU passthrough configured successfully!"
echo "Run 'vainfo' inside container to verify VAAPI support"
