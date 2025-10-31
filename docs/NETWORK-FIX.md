# Network Configuration Fix Summary

## Problem

VMs were receiving DHCP-assigned IPs (10.10.0.115+) instead of the configured static IPs (10.10.0.20-23), causing "no route to host" errors.

**Expected IPs:**
- Control plane: 10.10.0.20
- Worker 01: 10.10.0.21
- Worker 02: 10.10.0.22
- Worker 03: 10.10.0.23

**Actual IPs received:**
- 10.10.0.115+
- 10.10.0.116+
- etc.

## Root Cause

The Talos network configuration was using `deviceSelector.hardwareAddr` to match network interfaces by MAC address:

```yaml
deviceSelector:
  hardwareAddr: "52:54:00:10:10:20"
```

This approach is **unreliable during initial boot** because:
1. MAC address matching may fail if VMs boot before MACs are fully set
2. Talos falls back to DHCP when interface matching fails
3. DHCP server assigns random IPs from the pool

## Solution

Changed network configuration to use **interface names directly** instead of MAC address selectors:

```yaml
interface: "eth0"  # Direct interface name
```

### Updated Configuration

**Control Plane:**
- Interface: `eth0`
- IP: 10.10.0.20/24
- Gateway: 10.10.0.1

**Workers (Dual NIC):**
- Interface: `eth0` → 10.10.0.21-23 (management)
- Interface: `eth1` → 10.11.0.21-23 (storage/Mayastor)
- Gateway: 10.10.0.1 (via eth0)

### Why This Works

✅ **Predictable**: VirtIO network devices always enumerate as eth0, eth1, etc.
✅ **Reliable**: No dependency on MAC address matching
✅ **Immediate**: Static IPs applied on first boot
✅ **Standard**: Recommended approach in Talos documentation for VMs

## Changes Made

**File:** `infrastructure/terraform/data.tf`

**Lines Changed:**
- Line 2: Updated header comment
- Lines 117-134: Control plane network config
- Line 148: Updated worker section comment
- Lines 208-231: Worker network config (dual NIC)
- Lines 62-81: Storage node network config

**Commit:** `78b3240` - Fix network configuration to use interface names instead of MAC selectors

## Next Steps

### 1. Destroy Existing VMs (if already deployed)

If you already ran `terraform apply` and have VMs with wrong IPs:

```bash
cd infrastructure/terraform

# Destroy the existing cluster
terraform destroy

# Confirm destruction when prompted
```

### 2. Re-deploy with Fixed Configuration

```bash
# Pull latest changes
git pull origin claude/mayastor-three-workers-config-011CUfp1BrvU2U2ZwMUqpxUZ

# Verify the configuration
terraform plan

# Deploy the cluster
terraform apply
```

### 3. Verify Correct IPs

After deployment, verify VMs have the correct static IPs:

```bash
# Check control plane
ping 10.10.0.20

# Check workers
ping 10.10.0.21
ping 10.10.0.22
ping 10.10.0.23

# SSH to control plane and check interface
ssh root@10.10.0.20 ip addr show eth0
# Should show: inet 10.10.0.20/24

# SSH to worker and check both interfaces
ssh root@10.10.0.21 ip addr show
# eth0 should show: inet 10.10.0.21/24
# eth1 should show: inet 10.11.0.21/24
```

### 4. Verify Cluster Connectivity

```bash
# Check cluster status
export KUBECONFIG=infrastructure/terraform/generated/kubeconfig
kubectl get nodes -o wide

# Expected output:
NAME             STATUS   ROLES           AGE   VERSION   INTERNAL-IP
talos-cp-01      Ready    control-plane   5m    v1.34.1   10.10.0.20
talos-worker-01  Ready    <none>          5m    v1.34.1   10.10.0.21
talos-worker-02  Ready    <none>          5m    v1.34.1   10.10.0.22
talos-worker-03  Ready    <none>          5m    v1.34.1   10.10.0.23
```

## Additional Configuration Notes

### MAC Addresses Still Set

Even though we're not using MAC address selectors anymore, Terraform still sets fixed MAC addresses on the VMs:

**Management Network (vmbr0):**
- Control plane: `52:54:00:10:10:10`
- Worker 01: `52:54:00:10:10:11`
- Worker 02: `52:54:00:10:10:12`
- Worker 03: `52:54:00:10:10:13`

**Storage Network (vmbr1):**
- Worker 01: `52:54:00:10:11:11`
- Worker 02: `52:54:00:10:11:12`
- Worker 03: `52:54:00:10:11:13`

This is still useful for:
- DHCP reservations (if needed)
- Network monitoring/tracking
- Debugging

### DHCP Not Required

With static IP configuration, you **don't need DHCP** on the 10.10.0.0/24 network. However, if you have DHCP running:

**Option 1:** Disable DHCP on 10.10.0.0/24 (recommended)

**Option 2:** Configure DHCP reservations using the MAC addresses above

**Option 3:** Exclude 10.10.0.1-10.10.0.50 from DHCP pool

## Troubleshooting

### VMs Still Getting DHCP IPs

**Check:**
```bash
# Verify Talos configuration was applied
talosctl -n 10.10.0.20 get machineconfig

# Check network interface configuration
talosctl -n 10.10.0.20 get addresses
```

**If interface shows DHCP:**
1. Verify vmbr0 and vmbr1 bridges exist in Proxmox
2. Check that VMs have 2 network devices (workers) or 1 (control plane)
3. Verify Talos machine config was applied: `talosctl -n <ip> get machineconfig`

### Can't Reach Nodes

**Check:**
```bash
# From Proxmox host
ping 10.10.0.20

# Check VM console in Proxmox
# Navigate to: VM → Console
# Login and run: ip addr show

# Verify vmbr0 bridge
ip addr show vmbr0
# Should show: 10.10.0.1/24
```

### Workers Can't Join Cluster

**Verify control plane is reachable:**
```bash
# From worker
ping 10.10.0.20

# From Proxmox host
curl -k https://10.10.0.20:6443
# Should return: "Unauthorized" (means API is accessible)
```

## Related Documentation

- `MIGRATION-SUMMARY.md` - Overall architecture and migration guide
- `docs/DEPLOYMENT-FLOW.md` - Full deployment automation
- `docs/CLOUDFLARE-SETUP.md` - DNS and API configuration
- `docs/INFISICAL-SETUP.md` - Secrets management

## Summary

✅ **Fixed**: Network configuration now uses interface names
✅ **Committed**: Changes pushed to branch
✅ **Action Required**: Destroy and re-deploy cluster
✅ **Expected Result**: VMs get correct static IPs (10.10.0.20-23)

---

**Commit:** 78b3240
**Branch:** claude/mayastor-three-workers-config-011CUfp1BrvU2U2ZwMUqpxUZ
**Date:** October 31, 2025
