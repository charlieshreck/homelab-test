# OPNsense DHCP Reservations for Homelab

This document provides the MAC address to IP mappings required for DHCP reservations in OPNsense.

## Why DHCP Reservations?

After multiple attempts with static IP configuration in Talos (interface names, busPath selectors), the most reliable approach is to use MAC address selectors with DHCP enabled, then configure static IP assignments via DHCP reservations in your router (OPNsense).

## Management Network (10.10.0.0/24 - vmbr0)

Configure these reservations in OPNsense for the **10.10.0.0/24** network:

| Node | MAC Address | Reserved IP | Hostname |
|------|-------------|-------------|----------|
| Control Plane | `52:54:00:10:10:10` | `10.10.0.20` | talos-cp-01 |
| Worker 01 | `52:54:00:10:10:11` | `10.10.0.21` | talos-worker-01 |
| Worker 02 | `52:54:00:10:10:12` | `10.10.0.22` | talos-worker-02 |
| Worker 03 | `52:54:00:10:10:13` | `10.10.0.23` | talos-worker-03 |

## Storage Network (10.11.0.0/24 - vmbr1)

Configure these reservations in OPNsense for the **10.11.0.0/24** network:

| Node | MAC Address | Reserved IP | Purpose |
|------|-------------|-------------|---------|
| Worker 01 (storage) | `52:54:00:10:11:11` | `10.11.0.21` | Mayastor/TrueNAS |
| Worker 02 (storage) | `52:54:00:10:11:12` | `10.11.0.22` | Mayastor/TrueNAS |
| Worker 03 (storage) | `52:54:00:10:11:13` | `10.11.0.23` | Mayastor/TrueNAS |

## OPNsense Configuration Steps

### For Management Network (10.10.0.0/24):

1. Log in to OPNsense web interface
2. Navigate to **Services** → **DHCPv4** → **[Your LAN Interface]**
3. Scroll down to **DHCP Static Mappings for this interface**
4. Click **Add** for each reservation:

**Example for Control Plane:**
- **MAC Address**: `52:54:00:10:10:10`
- **IP Address**: `10.10.0.20`
- **Hostname**: `talos-cp-01`
- **Description**: `Talos Control Plane`
- Click **Save**

Repeat for all 4 nodes (control plane + 3 workers).

### For Storage Network (10.11.0.0/24):

1. Navigate to **Services** → **DHCPv4** → **[Your Storage Interface]**
2. Ensure DHCP is enabled on this interface with range (e.g., 10.11.0.100-10.11.0.200)
3. Add static mappings for the 3 workers:

**Example for Worker 01 Storage:**
- **MAC Address**: `52:54:00:10:11:11`
- **IP Address**: `10.11.0.21`
- **Hostname**: `talos-worker-01-storage`
- **Description**: `Worker 01 Storage Network (Mayastor)`
- Click **Save**

Repeat for workers 02 and 03.

## Verification

After configuring DHCP reservations and deploying VMs:

### Check DHCP Leases
In OPNsense:
- Navigate to **Services** → **DHCPv4** → **Leases**
- Verify all 7 MAC addresses have obtained their reserved IPs

### Check from Talos Nodes
Once VMs are running:

```bash
# Get kubeconfig
export TALOSCONFIG=~/.talos/config

# Check node IPs
talosctl -n 10.10.0.20 get addresses

# Should show:
# 10.10.0.20 on management interface
# 10.11.0.21 on storage interface (workers only)
```

### Verify Connectivity
```bash
# From control plane, ping all nodes
talosctl -n 10.10.0.20 get members

# Check storage network (workers only)
ping 10.11.0.21
ping 10.11.0.22
ping 10.11.0.23
```

## Troubleshooting

### Issue: VMs Still Getting Wrong IPs

**Symptoms:**
- VMs boot with IPs like 10.10.0.115+ instead of 10.10.0.20-23

**Solutions:**
1. **Check MAC addresses in Proxmox:**
   ```bash
   qm config 200  # Control plane
   qm config 201  # Worker 01
   qm config 202  # Worker 02
   qm config 203  # Worker 03
   ```
   Verify the MAC addresses match what's configured in OPNsense.

2. **Clear DHCP leases:**
   - In OPNsense, delete any existing leases for these MAC addresses
   - Restart VMs to request fresh DHCP leases

3. **Verify DHCP range:**
   - Ensure your DHCP range doesn't overlap with reserved IPs
   - Good range: 10.10.0.100-10.10.0.200 (leaves 10.10.0.1-99 for static/reserved)

4. **Check DHCP is actually enabled:**
   - In Talos config, verify `dhcp: true` is set (it should be now)
   - Run: `talosctl -n <node-ip> get addresses` to see DHCP status

### Issue: Storage Network Not Working

**Symptoms:**
- Mayastor pods can't communicate
- DiskPools show "Offline"

**Solutions:**
1. **Verify vmbr1 exists in Proxmox:**
   ```bash
   ip link show vmbr1
   ```
   If not, create it via Proxmox GUI.

2. **Check second NIC is present:**
   ```bash
   talosctl -n 10.10.0.21 get links
   # Should show 2 interfaces (eth0, eth1 or similar)
   ```

3. **Verify storage network connectivity:**
   ```bash
   # From worker-01, ping other workers on storage network
   talosctl -n 10.10.0.21 shell
   ping 10.11.0.22
   ping 10.11.0.23
   ```

## Summary

**Total DHCP Reservations Needed:** 7

- **Management Network (10.10.0.0/24):** 4 reservations (1 CP + 3 workers)
- **Storage Network (10.11.0.0/24):** 3 reservations (3 workers only)

**Next Steps:**
1. ✅ Code changes committed and pushed to GitHub
2. → Configure DHCP reservations in OPNsense (this document)
3. → Pull changes on terra LXC: `cd ~/homelab-test && git pull`
4. → Deploy with Terraform: `cd infrastructure/terraform && terraform apply`
5. → Verify VMs get correct IPs
6. → Check Mayastor deployment via ArgoCD

---

**Created:** November 1, 2025
**Cluster:** homelab-test on "the fal"
