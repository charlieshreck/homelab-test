#!/bin/bash
# Verify Proxmox host GPU prerequisites for Plex LXC
# Run this script on the Proxmox host: ssh root@10.10.0.151 'bash -s' < verify-proxmox-gpu.sh

set -euo pipefail

echo "============================================"
echo "Proxmox GPU Prerequisites Verification"
echo "============================================"
echo

# Check IOMMU
echo "[1/5] Checking IOMMU configuration..."
if grep -q "iommu=pt" /proc/cmdline; then
    echo "✓ IOMMU is enabled (iommu=pt)"
else
    echo "✗ IOMMU not enabled in kernel command line"
    echo "  Add 'iommu=pt' to /etc/default/grub and run 'update-grub'"
    EXIT_CODE=1
fi
echo

# Check AMD GPU driver
echo "[2/5] Checking AMD GPU driver..."
if lsmod | grep -q amdgpu; then
    echo "✓ AMD GPU driver (amdgpu) is loaded"
    lsmod | grep amdgpu | head -1
else
    echo "✗ AMD GPU driver not loaded"
    echo "  Ensure amdgpu module is loaded"
    EXIT_CODE=1
fi
echo

# Check DRI devices
echo "[3/5] Checking DRI devices..."
if [[ -e /dev/dri/renderD128 ]]; then
    echo "✓ /dev/dri/renderD128 exists"
    ls -la /dev/dri/
else
    echo "✗ /dev/dri/renderD128 not found"
    echo "  GPU render device missing"
    EXIT_CODE=1
fi
echo

# Check render group
echo "[4/5] Checking render group..."
RENDER_GID=$(stat -c '%g' /dev/dri/renderD128 2>/dev/null || echo "0")
if [[ "$RENDER_GID" != "0" ]]; then
    echo "✓ Render device GID: ${RENDER_GID}"
    getent group ${RENDER_GID} || echo "  (Group ID ${RENDER_GID})"
else
    echo "✗ Could not determine render device GID"
    EXIT_CODE=1
fi
echo

# Check Debian 12 template
echo "[5/5] Checking LXC templates..."
if pveam available | grep -q "debian-12-standard"; then
    echo "✓ Debian 12 template available"
    pveam available | grep debian-12-standard | head -1
else
    echo "⚠ Debian 12 template not found"
    echo "  Run: pveam update && pveam download local debian-12-standard_12.7-1_amd64.tar.zst"
fi
echo

# Summary
echo "============================================"
if [[ "${EXIT_CODE:-0}" == "0" ]]; then
    echo "✓ All prerequisites met!"
    echo "  Ready to deploy Plex LXC with GPU passthrough"
else
    echo "✗ Some prerequisites are missing"
    echo "  Fix the issues above before proceeding"
    exit 1
fi
echo "============================================"
