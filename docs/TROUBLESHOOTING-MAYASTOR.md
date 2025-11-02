# Troubleshooting Mayastor OpenEBS Storage

## Overview
This guide covers common issues with Mayastor (OpenEBS Replicated PV) deployment and operation.

---

## Issue 1: DiskPool CRD Not Found

### Symptom
```
resource mapping not found for name: "pool-worker-01"
no matches for kind "DiskPool" in version "openebs.io/v1beta2"
ensure CRDs are installed first
```

### Root Cause
DiskPool resources are being created before the Mayastor operator installs the CRDs.

### Solution
**Fixed in commit:** `Fix Mayastor namespace conflict and DiskPool sync wave timing`

The deployment now uses ArgoCD sync waves to ensure correct ordering:
- **Wave 0:** `mayastor-namespace` creates namespace with Pod Security labels
- **Wave 1:** `mayastor` operator installs CRDs
- **Wave 2:** `mayastor-config` creates DiskPools and StorageClasses

**If you still see this error:**
1. Check that all DiskPool resources have the sync-wave annotation:
   ```yaml
   metadata:
     annotations:
       argocd.argoproj.io/sync-wave: "2"
   ```

2. Verify CRDs are installed:
   ```bash
   kubectl get crd | grep openebs
   ```
   Should show: `diskpools.openebs.io` and other Mayastor CRDs

3. Force ArgoCD to re-sync:
   ```bash
   kubectl patch app mayastor-config -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge
   ```

---

## Issue 2: etcd Crash Loop - "member has already been bootstrapped"

### Symptom
```bash
$ kubectl get pods -n mayastor
NAME               READY   STATUS             RESTARTS   AGE
mayastor-etcd-0    1/1     Running            0          5m
mayastor-etcd-1    1/1     Running            0          5m
mayastor-etcd-2    0/1     CrashLoopBackOff   5          5m
```

**Logs show:**
```
{"level":"fatal","msg":"discovery failed",
 "error":"member 946609bde8186189 has already been bootstrapped"}
```

### Root Cause
etcd-2 has stale data from a previous deployment in `/bitnami/etcd/data`. Even though we configured `persistence.enabled: false`, the emptyDir volume retains data between pod restarts (but not node restarts). The pod tries to join as a "new" member but finds existing data, causing a conflict.

### Solution

**Option 1: Delete the etcd StatefulSet (Recommended - Fast Recovery)**

Delete the entire etcd StatefulSet to force clean recreation:

```bash
# Delete the etcd statefulset
kubectl delete statefulset mayastor-etcd -n mayastor

# ArgoCD will automatically recreate it with fresh pods
# Watch pods come back up (should take ~1-2 minutes)
kubectl get pods -n mayastor -l app.kubernetes.io/component=etcd -w
```

This forces all etcd pods to restart with fresh emptyDir volumes.

**Option 2: Delete Just the Problematic Pod**

```bash
# Delete the crashing pod
kubectl delete pod mayastor-etcd-2 -n mayastor

# Watch it restart
kubectl get pod mayastor-etcd-2 -n mayastor -w
```

⚠️ **Warning:** This may not work if stale data persists in the emptyDir. Use Option 1 if this fails.

**Option 3: Scale Down and Back Up**

```bash
# Scale etcd to 0 (clears all emptyDir volumes)
kubectl scale statefulset mayastor-etcd -n mayastor --replicas=0

# Wait for all pods to terminate
kubectl get pods -n mayastor -l app.kubernetes.io/component=etcd -w

# Scale back to 3
kubectl scale statefulset mayastor-etcd -n mayastor --replicas=3

# Watch pods come back
kubectl get pods -n mayastor -l app.kubernetes.io/component=etcd -w
```

### Verification

After applying the fix, verify all etcd pods are running:

```bash
$ kubectl get pods -n mayastor -l app.kubernetes.io/component=etcd
NAME              READY   STATUS    RESTARTS   AGE
mayastor-etcd-0   1/1     Running   0          2m
mayastor-etcd-1   1/1     Running   0          2m
mayastor-etcd-2   1/1     Running   0          2m
```

Check etcd cluster health:
```bash
# Get a shell on any etcd pod
kubectl exec -it mayastor-etcd-0 -n mayastor -- sh

# Check member list
etcdctl member list

# Check endpoint health
etcdctl endpoint health --cluster

# Exit the pod
exit
```

Expected output:
```
http://mayastor-etcd-0.mayastor-etcd-headless.mayastor.svc.cluster.local:2379 is healthy
http://mayastor-etcd-1.mayastor-etcd-headless.mayastor.svc.cluster.local:2379 is healthy
http://mayastor-etcd-2.mayastor-etcd-headless.mayastor.svc.cluster.local:2379 is healthy
```

---

## Issue 3: Pod Security Violations

### Symptom
```
Error creating: pods "mayastor-csi-controller-xxx" is forbidden:
violates PodSecurity "baseline:latest": host namespaces (hostNetwork=true)
```

### Root Cause
Mayastor requires privileged access (hostNetwork, hostPID, privileged containers) for low-level storage operations. The default Pod Security Standards block this.

### Solution
**Fixed in commit:** `Fix Mayastor Pod Security violations with privileged namespace`

The `mayastor` namespace now has Pod Security labels:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mayastor
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

**If you still see this error:**
1. Verify namespace has correct labels:
   ```bash
   kubectl get namespace mayastor -o yaml | grep pod-security
   ```

2. Re-sync the mayastor-namespace application:
   ```bash
   kubectl patch app mayastor-namespace -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge
   ```

---

## Issue 4: IO Engine Pods Pending or CrashLoopBackOff

### Symptom
```bash
$ kubectl get pods -n mayastor
NAME                          READY   STATUS    RESTARTS   AGE
mayastor-io-engine-9kg2p      0/1     Pending   0          5m
```

### Possible Causes and Solutions

#### Cause 1: Huge Pages Not Configured

**Check:**
```bash
# From terra LXC
export TALOSCONFIG=~/homelab-test/infrastructure/terraform/generated/talosconfig

# Check huge pages on worker nodes
talosctl -n 10.10.0.21 read /proc/meminfo | grep Huge
```

**Expected output:**
```
HugePages_Total:    1024
HugePages_Free:     1024
Hugepagesize:       2048 kB
```

**Fix:** Already configured in `infrastructure/terraform/data.tf`:
```hcl
sysctls = {
  "vm.nr_hugepages" = "1024"  # 2GiB huge pages
}
```

If not applied, destroy and recreate the cluster.

#### Cause 2: nvme-tcp Module Not Loaded

**Check:**
```bash
talosctl -n 10.10.0.21 read /proc/modules | grep nvme
```

**Expected:** Should show `nvme_tcp` module loaded.

**Fix:** Already configured in `infrastructure/terraform/data.tf`:
```hcl
kernel = {
  modules = [
    { name = "nvme-tcp" }
  ]
}
```

#### Cause 3: Missing Disk or Wrong Path

**Check:**
```bash
# List block devices on worker
talosctl -n 10.10.0.21 list /dev | grep sd
```

**Expected:** Should show `/dev/sdb` (Mayastor disk).

**Fix:** Verify in Proxmox that each worker has:
- Primary disk: `/dev/sda` (50GB for OS)
- Secondary disk: `/dev/sdb` (1TB total / ~300GB per node for Mayastor)

#### Cause 4: Insufficient CPU Resources

**Check:**
```bash
kubectl describe pod mayastor-io-engine-xxxx -n mayastor
```

**Look for:** `Insufficient cpu` in Events section.

**Fix:** IO engine requires 2 full CPU cores per node. Already configured in `values.yaml`:
```yaml
io_engine:
  resources:
    limits:
      cpu: "2"
```

If workers don't have 2 spare CPU cores, reduce the request or add more CPU to workers.

---

## Issue 5: DiskPools Not Creating or Offline

### Symptom
```bash
$ kubectl get diskpools -n mayastor
NAME             NODE              STATE     POOL_STATUS   CAPACITY      USED   AVAILABLE
pool-worker-01   talos-worker-01   Creating  Unknown       0 B           0 B    0 B
```

### Troubleshooting

#### Step 1: Check IO Engine Pods
```bash
kubectl get pods -n mayastor | grep io-engine
```

All IO engine pods must be Running before DiskPools can be created.

#### Step 2: Check DiskPool Events
```bash
kubectl describe diskpool pool-worker-01 -n mayastor
```

Look for error messages in Events section.

#### Step 3: Check Disk Availability
```bash
# Check if disk is visible to Mayastor
kubectl exec -it deployment/mayastor-operator-diskpool -n mayastor -- \
  mayastor-client node get
```

#### Step 4: Check IO Engine Logs
```bash
# Get logs from IO engine pod on the relevant worker
kubectl logs mayastor-io-engine-xxxx -n mayastor
```

**Common errors:**
- `device or resource busy` - Disk is already in use or has existing partitions
- `permission denied` - Wrong permissions on `/dev/sdb`
- `no such device` - Disk doesn't exist at specified path

### Solution: Clean Disk and Recreate DiskPool

**⚠️ WARNING:** This will erase all data on `/dev/sdb`!

```bash
# SSH to worker node (example: worker-01)
export TALOSCONFIG=~/homelab-test/infrastructure/terraform/generated/talosconfig
talosctl -n 10.10.0.21 shell

# Clear disk
wipefs -a /dev/sdb
sgdisk --zap-all /dev/sdb
exit

# Delete and recreate DiskPool
kubectl delete diskpool pool-worker-01 -n mayastor
kubectl patch app mayastor-config -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge
```

---

## Issue 6: ArgoCD Warning - SharedResourceWarning for Namespace

### Symptom
```
mayastor-config: SharedResourceWarning
Namespace/mayastor is part of applications argocd/mayastor-config and mayastor-namespace
```

### Root Cause
The namespace is managed by both applications:
- `mayastor-namespace` explicitly creates it (wave 0)
- `mayastor-config` references it via kustomization (wave 2)

### Solution
**Fixed in commit:** `Fix Mayastor namespace conflict and DiskPool sync wave timing`

Changes made:
1. Removed duplicate `Namespace` resource from `diskpools.yaml`
2. Removed `namespace: mayastor` field from `resources/kustomization.yaml`
3. DiskPool resources now explicitly specify `namespace: mayastor` in their metadata

This is a minor warning and doesn't affect functionality. ArgoCD can handle shared resources.

---

## Diagnostic Commands

### Quick Health Check
```bash
#!/bin/bash
echo "=== Mayastor Namespace ==="
kubectl get namespace mayastor

echo -e "\n=== Mayastor Pods ==="
kubectl get pods -n mayastor -o wide

echo -e "\n=== IO Engine Status ==="
kubectl get pods -n mayastor | grep io-engine

echo -e "\n=== etcd Status ==="
kubectl get pods -n mayastor | grep etcd

echo -e "\n=== DiskPools ==="
kubectl get diskpools -n mayastor

echo -e "\n=== StorageClasses ==="
kubectl get storageclass | grep mayastor

echo -e "\n=== PVs Using Mayastor ==="
kubectl get pv | grep mayastor || echo "No PVs yet"
```

### Check Mayastor CRDs
```bash
kubectl get crd | grep openebs
```

Expected output:
```
diskpools.openebs.io
volumes.openebs.io
...
```

### Check Node Labels
```bash
kubectl get nodes --show-labels | grep mayastor
```

Workers should have: `openebs.io/engine=mayastor`

### Test Storage Provisioning
```bash
# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-mayastor-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: mayastor-3
EOF

# Watch PVC get bound
kubectl get pvc test-mayastor-pvc -w

# Check PV was created
kubectl get pv | grep test-mayastor-pvc

# Clean up
kubectl delete pvc test-mayastor-pvc
```

---

## References

- [Mayastor Official Documentation](https://openebs.io/docs/user-guides/replicated-storage)
- [Mayastor Best Practices](https://openebs.io/docs/user-guides/replicated-storage/advanced-operations/best-practices)
- Repository: `kubernetes/platform/mayastor/`

---

**Created:** November 2, 2025
**Mayastor Version:** v2.9.3
**Cluster:** homelab-test (3 workers + 1 control plane)
