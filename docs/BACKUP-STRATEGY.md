# Backup Strategy

This document outlines the backup architecture for the homelab, including Kubernetes workload backups, persistent data backups, and non-Kubernetes system backups.

## Overview

The backup strategy uses a three-layer approach:

1. **Velero** - Kubernetes resource backups and PVC data
2. **Restic** - File-level backups for Kubernetes volumes (since Mayastor doesn't support snapshots)
3. **Restic LXC** - Non-Kubernetes system backups (TrueNAS, VMs, etc.)

All backups are stored on **MinIO** running on TrueNAS (10.20.0.103:9000).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Backup Targets                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
            ┌──────────────────────┐
            │   MinIO on TrueNAS   │
            │   (10.20.0.103:9000) │
            │   Bucket: velero     │
            │   Bucket: restic-lxc │
            └──────────────────────┘
                      ▲
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
    ┌────────┐   ┌─────────┐   ┌────────────────┐
    │ Velero │   │ Restic  │   │ Restic LXC     │
    │ Server │   │ Node    │   │ Container      │
    │        │   │ Agent   │   │ (Systemd       │
    │        │   │ (FS     │   │  Timer)        │
    │        │   │ Backup) │   │                │
    └────────┘   └─────────┘   └────────────────┘
        ▲             ▲              ▲
        │             │              │
        └─────────────┼──────────────┘
                      │
        ┌─────────────────────────────┐
        │   Kubernetes Cluster        │
        │                             │
        │  - Deployments              │
        │  - Services                 │
        │  - PVCs (Mayastor volumes)  │
        └─────────────────────────────┘
```

## Layer 1: Velero (Kubernetes Workloads)

### Purpose
- Backs up Kubernetes manifests (Deployments, ConfigMaps, Secrets, etc.)
- Backs up PVC data using Restic (filesystem-level backups)
- Enables disaster recovery for the entire cluster

### Configuration
- **Provider**: AWS (S3-compatible via MinIO)
- **Bucket**: `velero-backups`
- **MinIO Endpoint**: `http://10.20.0.103:9000`
- **Backup Storage Location**: Minio
- **Volume Snapshot Location**: Removed (Mayastor doesn't support CSI snapshots)
- **Node Agent**: Enabled for file-level backups using Restic

### Backup Schedule
Configured via `kubernetes/platform/velero/schedules/` with retention policies:
- **Daily**: Last 7 days
- **Weekly**: Last 4 weeks
- **Monthly**: Last 12 months

### How It Works

1. **Kubernetes Resources**
   - Velero server watches for backup schedule
   - Exports Deployments, Services, ConfigMaps, Secrets, etc. to MinIO
   - Stores entire K8s state in S3

2. **Persistent Volumes**
   - Node agent (DaemonSet) runs on Mayastor nodes
   - When backing up a PVC, Restic mounts the volume
   - Files are compressed and deduplicated
   - Restic snapshots stored in MinIO

### Velero CLI Examples

```bash
# List backups
velero backup get

# Create on-demand backup
velero backup create backup-$(date +%Y%m%d-%H%M%S)

# Restore from backup
velero restore create --from-backup backup-20250101-000000

# Check backup logs
velero backup logs backup-name

# View volume backup details
velero backup describe backup-name --details
```

## Layer 2: Restic (Filesystem-Level Backups)

### Purpose
- File-level incremental backups of Mayastor volumes
- Deduplication and compression
- Encrypted backups

### Why Restic Instead of Snapshots?
Mayastor does NOT support CSI snapshot providers. Instead:
- Velero's node agent uses Restic to mount and backup PVCs
- Filesystem-level incremental backups
- No dependency on snapshot drivers
- Works with any storage backend

### Configuration
- **Repository**: S3-compatible (MinIO)
- **Encryption**: Password-based encryption
- **Deduplication**: Full content-based deduplication
- **Compression**: zstd compression

### How Velero + Restic Works

```
1. Backup Trigger
   └─> Velero determines PVC needs backup

2. Restic Initialization
   └─> Node agent initializes Restic repository in MinIO

3. Volume Mount
   └─> Node agent mounts PVC read-only

4. Backup Process
   └─> Restic scans filesystem
       └─> Hashes all files
       └─> Compares with previous backup
       └─> Uploads only changed blocks

5. Upload to MinIO
   └─> Restic stores encrypted snapshots
       └─> Metadata stored in MinIO
       └─> Old snapshots retained per policy

6. Snapshot Metadata
   └─> Velero stores restore instructions
       └─> PVC size, filesystem info
       └─> Snapshot ID for future restores
```

## Layer 3: Restic LXC (Non-Kubernetes Backups)

### Purpose
- Backups for systems outside Kubernetes
- TrueNAS datasets, VMs, configuration files
- Independent from cluster health

### Configuration
- **Type**: LXC container with Restic
- **Host**: 10.10.0.25 (restic-backup)
- **Repository**: `s3:http://10.20.0.103:9000/restic-backups`
- **Backup Target**: Configurable paths
- **Schedule**: Systemd timer (default: daily at 2:00 AM)

### What Gets Backed Up
Configure backup paths in `/etc/restic.env` and systemd timer:
- TrueNAS dataset snapshots
- Plex metadata and configuration
- Application configuration files
- Database exports

### Restic LXC Setup

The Restic LXC is provisioned by Terraform (`infrastructure/terraform/modules/restic-lxc/`):

```bash
# SSH to Restic LXC
ssh -l root 10.10.0.25

# Check backup status
systemctl status restic-backup.timer
journalctl -u restic-backup.service -f

# List backups
source /etc/restic.env
restic snapshots

# Restore files
restic restore <snapshot-id> --target /restore
```

### Backup Job Configuration

**Service**: `/etc/systemd/system/restic-backup.service`
- Runs Restic backup command
- Sources `/etc/restic.env` for credentials
- Logs to systemd journal

**Timer**: `/etc/systemd/system/restic-backup.timer`
- Triggers daily at configured time
- Persistent: catches up if system was down
- Uses OnBootSec to run shortly after reboot

### Adding New Backup Paths

Edit `/etc/systemd/system/restic-backup.service`:

```bash
[Service]
ExecStart=restic backup /path/to/backup1 /path/to/backup2 --tag production
```

Then restart:
```bash
systemctl daemon-reload
systemctl restart restic-backup.timer
```

## Backup Locations

### S3 Bucket Structure on MinIO

```
minio/
├── velero-backups/
│   ├── restic/
│   │   └── (Restic snapshots for PVCs)
│   └── (Velero metadata)
└── restic-backups/
    ├── (Restic snapshots for non-K8s)
    └── (LXC backups)
```

### MinIO Access

```bash
# MinIO endpoint
mc alias set minio http://10.20.0.103:9000 <access-key> <secret-key>

# List buckets
mc ls minio/

# Check bucket size
mc du minio/velero-backups

# Browse backups
mc ls --recursive minio/velero-backups
```

## Retention Policies

### Velero (Kubernetes)

**Daily Backups** (sync-wave dependent)
```yaml
retentionDays: 7  # Keep last 7 daily backups
```

**Weekly Backups**
```yaml
schedule: "0 2 * * 0"  # Every Sunday at 2 AM
retentionDays: 28     # Keep last 4 weeks
```

**Monthly Backups**
```yaml
schedule: "0 3 1 * *"  # First of month at 3 AM
retentionDays: 365    # Keep last 12 months
```

### Restic LXC (Non-Kubernetes)

Policy in systemd timer (adjust as needed):
```bash
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12
```

## Testing Backups

### Velero Backup Test

```bash
# Create test deployment with PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-test
  namespace: default
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: mayastor-1
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backup-test-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test
        image: busybox:latest
        command: ['sh', '-c', 'echo "test data" > /data/test.txt && sleep 3600']
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: backup-test
EOF

# Wait for PVC to bind
kubectl wait --for=condition=Bound pvc/backup-test --timeout=300s

# Trigger backup
velero backup create test-backup

# Monitor backup progress
watch velero backup describe test-backup --details

# Verify backup contains data
velero backup logs test-backup | tail -50
```

### Restic LXC Test

```bash
# SSH to Restic LXC
ssh root@10.10.0.25

# Test backup manually
source /etc/restic.env
restic backup /root/test-data

# Verify snapshot was created
restic snapshots

# List files in snapshot
restic ls <snapshot-id>

# Test restore to /tmp
restic restore <snapshot-id> --target /tmp/restore-test
ls /tmp/restore-test
```

## Disaster Recovery

### Full Cluster Recovery

1. **Restore from Velero backup**
   ```bash
   velero restore create --from-backup <backup-name> --wait
   ```

2. **Verify restored resources**
   ```bash
   kubectl get all -A
   kubectl get pvc -A
   ```

3. **Check PVC data**
   ```bash
   kubectl exec -it <pod> -- ls /data
   ```

### Single PVC Recovery

```bash
# List available snapshots
velero backup describe <backup-name> --details | grep -i "PVC\|Snapshot"

# Restore specific PVC
velero restore create --from-backup <backup-name> \
  --include-resources persistentvolumeclaims \
  --namespace <target-namespace> \
  --wait
```

### Recover Non-Kubernetes Data

```bash
# SSH to Restic LXC
ssh root@10.10.0.25

# List snapshots
source /etc/restic.env
restic snapshots

# Restore specific snapshot
restic restore <snapshot-id> --target /restore

# Copy restored files
cp -r /restore/* /original/location/
```

## Monitoring Backups

### Check Backup Status

```bash
# Velero
velero backup get
velero backup describe <backup-name>

# Restic LXC
ssh root@10.10.0.25 'systemctl status restic-backup.timer'
ssh root@10.10.0.25 'journalctl -u restic-backup.service | tail -20'
```

### Backup Size Monitoring

```bash
# MinIO usage
mc du minio/velero-backups
mc du minio/restic-backups

# Velero storage
kubectl logs -n velero -l app.kubernetes.io/name=velero -f
```

### Alert on Failed Backups

Velero creates Kubernetes events for failed backups:
```bash
kubectl get events -n velero --sort-by='.lastTimestamp'
```

## Migration from Longhorn

If migrating from Longhorn snapshots to Velero + Restic:

1. Export Longhorn volumes as backups
2. Create Velero backup including those volumes
3. Delete Longhorn volumes after verification
4. Update PVC storage class to mayastor-1
5. Restore via Velero if needed

## Performance Tuning

### Velero Node Agent Settings

```yaml
# In velero-app.yaml
nodeAgent:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 1Gi  # Increased for large volumes
```

### Restic Performance

For faster backups, adjust:
```bash
# In /etc/restic.env
export RESTIC_PROCS=4  # Parallel uploads (default: 1)
export RESTIC_CACHE_DIR=/var/cache/restic
```

## References

- [Velero Documentation](https://velero.io/docs/)
- [Restic Documentation](https://restic.readthedocs.io/)
- [MinIO Documentation](https://docs.min.io/)
- [Mayastor Documentation](https://mayastor.gitbook.io/)

---

**Last Updated**: November 30, 2025
**Backup Strategy Version**: 1.0
