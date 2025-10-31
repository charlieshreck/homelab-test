# Homelab Migration Summary - "The Fal"

## Overview
This document summarizes the migration from a single-worker setup to a 3-worker Mayastor-based homelab running on new hardware.

## Hardware Configuration

### New System: "The Fal"
- **CPU**: Ryzen 9 6800HX (8 cores, 16 threads)
- **RAM**: 32GB
- **Storage**:
  - **local-lvm**: 140GB for VM disks
  - **helford**: 1TB dedicated storage for Mayastor
- **Network**: Dedicated 2.5Gbe interface on 10.10.0.0/24

## Network Architecture

### Primary Network (Management) - 10.10.0.0/24
- **Gateway**: 10.10.0.1
- **Bridge**: vmbr0
- **Control Plane**: 10.10.0.10
- **Workers**:
  - worker-01: 10.10.0.11
  - worker-02: 10.10.0.12
  - worker-03: 10.10.0.13
- **LoadBalancer Pool**: 10.10.0.50-10.10.0.99

### Storage Network - 10.11.0.0/24
- **Gateway**: 10.11.0.1
- **Bridge**: vmbr1
- **Workers**:
  - worker-01: 10.11.0.11
  - worker-02: 10.11.0.12
  - worker-03: 10.11.0.13

This dual-NIC setup provides:
- Isolated storage traffic for Mayastor replication
- Dedicated network for TrueNAS NFS/SMB access
- Better performance and security

## Cluster Configuration

### VM Resource Allocation
| VM | vCPUs | RAM | OS Disk | Storage Disk | Purpose |
|---|---|---|---|---|---|
| **Control Plane** | 2 | 4GB | 30GB | - | K8s control plane |
| **Worker 01** | 2 | 9GB | 30GB | 300GB | Mayastor + workloads |
| **Worker 02** | 2 | 9GB | 30GB | 300GB | Mayastor + workloads |
| **Worker 03** | 2 | 9GB | 30GB | 300GB | Mayastor + workloads |
| **Total Allocated** | 8 | 31GB | 120GB | 900GB | |
| **Proxmox Overhead** | - | ~1GB | 20GB | 100GB | Host OS |

### Storage Architecture

#### Mayastor (OpenEBS)
- **Version**: 2.8.0
- **Replicas**: 3-way replication across workers
- **Disk per node**: 300GB (/dev/sdb)
- **Total capacity**: ~900GB raw (varies by replication factor)
- **Network**: Dedicated 10.11.0.0/24 storage network
- **Protocol**: NVMe-oF over TCP

**Features**:
- High-performance block storage
- Native NVMe performance
- Huge pages enabled (1024 pages per node)
- Thin provisioning
- Snapshots and clones

#### Configuration Changes from Longhorn
- Removed Longhorn (filesystem-based, iSCSI)
- Added Mayastor (block-based, NVMe-oF)
- Changed kernel module from `iscsi_tcp` to `nvme-tcp`
- Added huge pages support via sysctls
- Raw block devices (no partitioning)

## Networking Changes

### Load Balancer Migration: MetalLB → Cilium

#### Removed
- MetalLB Helm release
- MetalLB IP pool (10.30.0.65-10.30.0.100)
- MetalLB L2 advertisements
- MetalLB annotations on services

#### Added
- Cilium L2 announcements enabled
- Cilium LoadBalancer IP Pool (10.10.0.50-10.10.0.99)
- Cilium L2 announcement policy
- External IPs support

#### Service Updates
| Service | Old IP | New IP | Change |
|---|---|---|---|
| Traefik | 10.30.0.100 | 10.10.0.80 | Updated annotation to `io.cilium/lb-ipam-ips` |
| Longhorn UI | 10.30.0.70 | - | Disabled (replaced by Mayastor) |
| ArgoCD | 10.30.0.80 | Auto | Using Cilium LB pool |

### Benefits of Cilium LB
- Native integration with Cilium CNI
- Better performance (no separate controller)
- Simpler architecture
- Direct Server Return (DSR) support
- L7 load balancing capability

## Application Changes

### Removed from Kubernetes
- **Plex Media Server**
  - Moved to LXC container with AMD 680 GPU passthrough
  - Reason: Direct GPU access for hardware transcoding
  - Benefit: Better performance, lower K8s overhead

### Disabled
- **Longhorn** (replaced by Mayastor)
  - Files renamed to `.disabled` to preserve configuration
  - Can be re-enabled if needed

## Talos Configuration Changes

### Worker Node Configuration
```yaml
# Kernel modules
modules:
  - nvme-tcp  # Changed from iscsi_tcp

# Sysctls for Mayastor
sysctls:
  vm.nr_hugepages: "1024"       # NEW: Huge pages for Mayastor
  vm.overcommit_memory: "1"
  vm.panic_on_oom: "0"

# Network interfaces (dual NIC)
interfaces:
  - eth0: 10.10.0.11/24         # Management
  - eth1: 10.11.0.11/24         # Storage (NEW)
```

### Removed
- Longhorn disk partitions
- Longhorn kubelet extraMounts
- iSCSI kernel modules

## TrueNAS Integration

### Dual NIC Support Added
The TrueNAS VM module now supports:
- Primary NIC: Management (10.10.0.0/24)
- Secondary NIC: Storage traffic (10.11.0.0/24)

This allows:
- Isolated NFS/SMB traffic from Kubernetes workloads
- Better performance for media streaming
- Network segmentation for security

## Terraform Module Changes

### talos-vm Module
**Added**:
- `enable_storage_network` - Boolean to enable second NIC
- `storage_bridge` - Bridge for storage network (vmbr1)
- `storage_mac_address` - MAC for second NIC

**Changed**:
- `longhorn_disk` → `mayastor_disk`
- Dynamic network device block for storage NIC

### truenas-vm Module
**Added**:
- `enable_storage_network` - Boolean to enable second NIC
- `storage_bridge` - Bridge for storage network
- `storage_mac_address` - MAC for second NIC

### Variables
**Added**:
- `storage_bridge` - Proxmox bridge for storage network
- `storage_gateway` - Gateway for storage network
- `cilium_lb_ip_pool` - IP range for Cilium LB

**Changed**:
- `proxmox_longhorn_storage` → `proxmox_mayastor_storage`
- `metallb_ip_range` → `cilium_lb_ip_pool`
- Workers now include `storage_ip` field

**Removed**:
- MetalLB-specific variables

### Locals
**Added**:
- `storage_mac_addresses` - MAC allocation for storage NICs
  - Format: `52:54:00:10:11:XX` for 10.11.0.0/24 network

**Changed**:
- MAC prefix: `52:54:00:10:30:XX` → `52:54:00:10:10:XX`

## Deployment Order

### 1. Infrastructure (Terraform)
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

This will:
1. Create 1 CP + 3 workers with dual NICs
2. Install Talos OS with Mayastor kernel modules
3. Bootstrap Kubernetes cluster
4. Install Cilium CNI with LB support
5. Deploy ArgoCD

### 2. Mayastor Setup
After cluster is up:
```bash
# Label nodes for Mayastor (done automatically by Terraform)
kubectl label nodes talos-worker-01 openebs.io/engine=mayastor
kubectl label nodes talos-worker-02 openebs.io/engine=mayastor
kubectl label nodes talos-worker-03 openebs.io/engine=mayastor

# Mayastor will be deployed by ArgoCD
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=mayastor -n mayastor --timeout=600s

# Create storage pools (manual step)
kubectl mayastor create pool pool-worker-01 talos-worker-01 /dev/sdb
kubectl mayastor create pool pool-worker-02 talos-worker-02 /dev/sdb
kubectl mayastor create pool pool-worker-03 talos-worker-03 /dev/sdb

# Create storage class
kubectl apply -f kubernetes/platform/mayastor/storageclass.yaml
```

### 3. Platform Services (ArgoCD)
ArgoCD will automatically deploy:
- Mayastor storage
- Traefik ingress
- Cert-manager
- External Secrets
- Media apps (minus Plex)

## Post-Migration Tasks

### Required Manual Steps

1. **Proxmox Network Setup**
   - Create `vmbr1` bridge for storage network
   - Assign physical interface or VLAN
   - Configure 10.11.0.0/24 subnet

2. **Mayastor Storage Pools**
   - Create pools on each worker (see above)
   - Verify pool status: `kubectl mayastor get pools`

3. **Plex LXC Container**
   - Create LXC with GPU passthrough
   - Install Plex Media Server
   - Mount TrueNAS NFS shares
   - Configure AMD 680 GPU for transcoding

4. **TrueNAS Configuration**
   - Deploy TrueNAS VM (currently commented out)
   - Configure dual NICs (10.10.0.x and 10.11.0.x)
   - Set up NFS exports on storage network
   - Update application NFS mounts to use 10.11.0.x

5. **DNS/DHCP Updates**
   - Update DHCP reservations for new IPs
   - Update DNS records for services
   - Update Cloudflare tunnel endpoints

### Validation Steps

```bash
# Check cluster health
kubectl get nodes -o wide
kubectl get pods -A

# Verify Cilium
cilium status
kubectl get svc -A | grep LoadBalancer

# Verify Mayastor
kubectl mayastor get nodes
kubectl mayastor get pools
kubectl get sc

# Check storage
kubectl get pvc -A
kubectl get pv

# Test storage
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: mayastor-3
EOF
```

## Rollback Plan

If issues occur:

1. **Revert to single worker**
   ```bash
   git checkout <previous-commit>
   terraform apply
   ```

2. **Re-enable Longhorn**
   ```bash
   cd kubernetes/platform
   mv longhorn-app.yaml.disabled longhorn-app.yaml
   mv longhorn-ingress-app.yaml.disabled longhorn-ingress-app.yaml
   mv longhorn-rbac-app.yaml.disabled longhorn-rbac-app.yaml
   ```

3. **Re-enable MetalLB**
   - Restore MetalLB section in `main.tf`
   - Update service annotations back to MetalLB format

## Performance Expectations

### Mayastor vs Longhorn
| Metric | Longhorn | Mayastor | Improvement |
|---|---|---|---|
| Sequential Read | ~200 MB/s | ~800 MB/s | 4x |
| Sequential Write | ~150 MB/s | ~600 MB/s | 4x |
| Random IOPS | ~2K | ~20K | 10x |
| Latency | ~5ms | ~0.5ms | 10x |

### Network Separation Benefits
- Storage traffic isolated from management
- Predictable performance for replication
- Better troubleshooting and monitoring
- Improved security posture

## Monitoring and Troubleshooting

### Key Metrics to Monitor
```bash
# Mayastor pools
kubectl mayastor get pools

# Node resources
kubectl top nodes

# Storage usage
kubectl get pv

# Network connectivity on storage network
kubectl exec -it <worker-pod> -- ping 10.11.0.11
```

### Common Issues

#### Mayastor pods not starting
- Check huge pages: `kubectl exec <pod> -- cat /proc/meminfo | grep Huge`
- Verify disk: `lsblk` on worker nodes
- Check kernel module: `lsmod | grep nvme`

#### Cilium LB not working
- Verify L2 announcements: `kubectl get ciliuml2announcementpolicies`
- Check IP pool: `kubectl get ciliumloadbalancerippool`
- Inspect Cilium logs: `kubectl logs -n kube-system -l k8s-app=cilium`

#### Storage network connectivity
- Verify second NIC on workers
- Check routing: `ip route` on worker nodes
- Test connectivity: `ping 10.11.0.1`

## Next Steps

1. ✅ Complete Terraform migration
2. ⏳ Test cluster deployment
3. ⏳ Configure Mayastor storage pools
4. ⏳ Deploy Plex LXC with GPU
5. ⏳ Set up TrueNAS with dual NICs
6. ⏳ Migrate workloads to Mayastor volumes
7. ⏳ Performance testing and optimization

## References

- [Mayastor Documentation](https://mayastor.gitbook.io/)
- [Cilium LoadBalancer](https://docs.cilium.io/en/stable/network/lb-ipam/)
- [Talos Linux](https://www.talos.dev/)
- [OpenEBS](https://openebs.io/)

---

**Migration Date**: October 31, 2025
**Cluster Name**: homelab-test
**Proxmox Node**: fal (formerly Carrick)
