# Troubleshooting Kubernetes API Connection Issues

## Symptom
Terraform hangs at `null_resource.wait_for_cluster` trying to connect to Kubernetes API, even though Talos dashboard shows cluster is healthy.

## Root Causes

1. **VMs got wrong IPs** - DHCP reservations not configured
2. **Terraform can't reach control plane** - Firewall or routing issue from terra LXC
3. **Kubernetes not bootstrapped yet** - Talos is up but K8s isn't
4. **Kubeconfig has wrong endpoint** - Points to wrong IP

## Troubleshooting Steps

### Step 1: Verify VM IPs (from Proxmox or VMs directly)

**Check from Proxmox:**
```bash
# SSH to Proxmox host (fal)
ssh root@10.10.0.1

# Check running VMs
qm list

# Check VM network for control plane (VM ID 200)
qm guest cmd 200 network-get-interfaces
```

**Or check in Proxmox GUI:**
- Go to each VM → Summary → IPs
- Verify:
  - Control plane: 10.10.0.20
  - Worker 01: 10.10.0.21
  - Worker 02: 10.10.0.22
  - Worker 03: 10.10.0.23

**If VMs have wrong IPs (10.10.0.115+):**
→ You didn't configure the DHCP reservations in OPNsense yet!
→ Follow: `docs/OPNSENSE-DHCP-RESERVATIONS.md`

### Step 2: Test Network Connectivity from Terra LXC

**Can terra reach the control plane?**
```bash
# From terra LXC
ping 10.10.0.20

# Can you reach the Talos API?
curl -k https://10.10.0.20:50000/health || echo "Talos API not reachable"

# Can you reach the Kubernetes API?
curl -k https://10.10.0.20:6443/healthz || echo "K8s API not reachable"
```

**If ping fails:**
- Check terra LXC can route to 10.10.0.0/24 network
- Check OPNsense firewall rules allow terra → K8s traffic

**If Talos API works but K8s API doesn't:**
- Kubernetes hasn't started yet (see Step 3)

### Step 3: Check Kubernetes Bootstrap Status

**Is Kubernetes actually running?**
```bash
# From terra LXC
cd ~/homelab-test/infrastructure/terraform
export TALOSCONFIG=./generated/talosconfig

# Check control plane status
talosctl -n 10.10.0.20 service kubelet

# Check if etcd is running (control plane needs this)
talosctl -n 10.10.0.20 service etcd

# Get all services
talosctl -n 10.10.0.20 services
```

**Look for:**
- `kubelet` - should be "Running"
- `etcd` - should be "Running" on control plane
- `kube-apiserver` - should be "Running" on control plane

**If services aren't running:**
```bash
# Check control plane logs
talosctl -n 10.10.0.20 logs kubelet
talosctl -n 10.10.0.20 logs etcd

# Check for bootstrap issues
talosctl -n 10.10.0.20 dmesg | tail -100
```

### Step 4: Verify Talosconfig and Kubeconfig

**Check Talosconfig endpoint:**
```bash
cat infrastructure/terraform/generated/talosconfig | grep endpoints
```
Should show: `endpoints: ["10.10.0.20"]`

**Check Kubeconfig endpoint:**
```bash
cat infrastructure/terraform/generated/kubeconfig | grep server
```
Should show: `server: https://10.10.0.20:6443`

**If endpoints are wrong:**
- Your VMs got wrong IPs
- Terraform used the wrong IP when generating configs
- Fix: Configure DHCP reservations, destroy/recreate VMs

### Step 5: Manual Kubernetes Bootstrap (if needed)

**If Kubernetes never started, bootstrap manually:**
```bash
# Bootstrap the control plane
talosctl -n 10.10.0.20 bootstrap

# Wait 2-3 minutes, then check services
talosctl -n 10.10.0.20 service kube-apiserver
```

### Step 6: Test Kubernetes API Manually

**Once K8s API is running, test it:**
```bash
export KUBECONFIG=./generated/kubeconfig

# Test connection
kubectl get --raw /healthz

# Check nodes
kubectl get nodes

# Expected output:
# NAME              STATUS     ROLES           AGE   VERSION
# talos-cp-01       NotReady   control-plane   1m    v1.31.x
# talos-worker-01   NotReady   <none>          30s   v1.31.x
# talos-worker-02   NotReady   <none>          30s   v1.31.x
# talos-worker-03   NotReady   <none>          30s   v1.31.x
```

**Nodes will be NotReady until Cilium is installed** (Terraform does this next).

### Step 7: Check for Port Conflicts

**Is something else listening on 6443?**
```bash
# From terra LXC
nmap -p 6443 10.10.0.20

# Should show: 6443/tcp open  kubernetes
```

## Common Issues and Solutions

### Issue 1: VMs Have Wrong IPs

**Problem:** VMs got 10.10.0.115+ instead of 10.10.0.20-23

**Solution:**
1. Configure DHCP reservations in OPNsense (see `docs/OPNSENSE-DHCP-RESERVATIONS.md`)
2. Destroy and recreate VMs:
   ```bash
   terraform destroy
   terraform apply
   ```

### Issue 2: Terra LXC Can't Route to 10.10.0.0/24

**Problem:** `ping 10.10.0.20` times out from terra

**Solution:**
1. Check terra LXC's default gateway:
   ```bash
   ip route show
   ```
2. Should have route to 10.10.0.0/24 via OPNsense
3. If not, add route or fix terra's network config in Proxmox

### Issue 3: OPNsense Firewall Blocking Traffic

**Problem:** Ping works but HTTPS doesn't

**Solution:**
1. Log in to OPNsense
2. Go to **Firewall** → **Rules** → **LAN**
3. Ensure rule allows traffic from terra's IP to 10.10.0.0/24 on ports 6443, 50000

### Issue 4: Kubernetes Never Bootstrapped

**Problem:** Talos is running but `kube-apiserver` service never started

**Solution:**
```bash
# Manually bootstrap
talosctl -n 10.10.0.20 bootstrap

# Watch logs
talosctl -n 10.10.0.20 logs -f kube-apiserver
```

### Issue 5: Cilium Not Installing (Nodes Stay NotReady)

**Problem:** Nodes appear but stay NotReady forever

**This is expected!** Terraform installs Cilium after API is reachable. Let Terraform continue.

## Quick Diagnostic Command

Run this from terra LXC to get all info at once:

```bash
#!/bin/bash
echo "=== VM IP Check ==="
ping -c 1 10.10.0.20 && echo "Control plane reachable" || echo "Control plane NOT reachable"

echo -e "\n=== Talos API Check ==="
curl -k -m 5 https://10.10.0.20:50000/health && echo "Talos API OK" || echo "Talos API FAILED"

echo -e "\n=== Kubernetes API Check ==="
curl -k -m 5 https://10.10.0.20:6443/healthz && echo "K8s API OK" || echo "K8s API FAILED"

echo -e "\n=== Talos Services ==="
export TALOSCONFIG=~/homelab-test/infrastructure/terraform/generated/talosconfig
talosctl -n 10.10.0.20 services | grep -E "etcd|kubelet|apiserver"

echo -e "\n=== Kubernetes Nodes ==="
export KUBECONFIG=~/homelab-test/infrastructure/terraform/generated/kubeconfig
kubectl get nodes 2>&1
```

Save this as `diagnose.sh` and run it to see where the problem is.

## What to Check Now

**Based on your situation (Talos healthy, K8s API not responding):**

1. **First:** Verify VMs have correct IPs (10.10.0.20-23)
   - If not → Configure DHCP reservations in OPNsense

2. **Second:** Test connectivity from terra LXC
   ```bash
   ping 10.10.0.20
   curl -k https://10.10.0.20:6443/healthz
   ```

3. **Third:** Check if Kubernetes services are running
   ```bash
   talosctl -n 10.10.0.20 service kube-apiserver
   ```

4. **Fourth:** If nothing is wrong, just wait longer
   - First boot can take 5-10 minutes for K8s to start
   - Check `talosctl -n 10.10.0.20 logs kubelet` for progress

---

**Created:** November 1, 2025
**For cluster:** homelab-test on "the fal"
