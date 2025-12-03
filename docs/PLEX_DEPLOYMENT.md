# Plex LXC Deployment with AMD 680M GPU Passthrough

## Overview

This document describes the deployment of Plex Media Server in a Proxmox LXC container with AMD Radeon 680M iGPU passthrough for hardware transcoding.

**Architecture Decision**: LXC container over full VM passthrough because:
- No vBIOS extraction required
- No GPU reset bugs
- Multiple containers can share GPU
- Identical VAAPI transcoding performance
- Simpler, more reliable

## Prerequisites

Before deploying, verify these prerequisites on the Proxmox host:

```bash
# Run verification script
ssh root@10.10.0.151 'bash -s' < infrastructure/scripts/verify-proxmox-gpu.sh
```

Required:
1. IOMMU enabled (`iommu=pt` in GRUB)
2. AMD GPU driver loaded (`amdgpu`)
3. `/dev/dri/renderD128` exists
4. Debian 12 LXC template downloaded
5. TrueNAS NFS exports configured

## Infrastructure Components

### Network Configuration
- **Management IP**: 10.10.0.60 (vmbr0)
- **Storage IP**: 10.11.0.60 (vmbr1)
- **TrueNAS NFS**: 10.11.0.5:/mnt/Tongariro/Plexopathy

### Container Specifications
- **VM ID**: 220
- **CPUs**: 4 cores
- **RAM**: 8GB
- **Disk**: 100GB (local-lvm)
- **Type**: Privileged (required for GPU access)

### Backup Configuration
- **Repository**: MinIO S3 (10.10.0.70:9000/plex-backups)
- **Schedule**: Daily at 03:00
- **Retention**: 7 daily, 4 weekly, 12 monthly

## Deployment Steps

### 1. Verify Prerequisites

```bash
ssh root@10.10.0.151 'bash -s' < infrastructure/scripts/verify-proxmox-gpu.sh
```

### 2. Set Environment Variables

```bash
export RESTIC_PASSWORD="your-restic-password"
export MINIO_ACCESS_KEY="your-minio-access-key"
export MINIO_SECRET_KEY="your-minio-secret-key"
export PLEX_CLAIM="claim-xxxxxxxxxxxxx"  # Optional
```

### 3. Deploy with Terraform

```bash
cd infrastructure/terraform

# Initialize
terraform init

# Plan
terraform plan -target=module.plex

# Apply
terraform apply -target=module.plex
```

The Terraform deployment will:
1. Create the LXC container with dual NICs
2. Configure GPU passthrough via script
3. Run Ansible to configure Plex

### 4. Verify Deployment

```bash
# Check container status
ssh root@10.10.0.151 pct status 220

# Verify GPU access
ssh root@10.10.0.60 'ls -la /dev/dri/'

# Check VAAPI support
ssh root@10.10.0.60 'vainfo --display drm --device /dev/dri/renderD128'

# Verify Plex is running
curl -I http://10.10.0.60:32400/web
```

### 5. Complete Plex Setup

1. Visit http://10.10.0.60:32400/web
2. Sign in with your Plex account
3. Add library pointing to `/data`
4. Enable Hardware Transcoding:
   - Settings > Transcoder
   - Enable "Use hardware acceleration when available"

## Manual Operations

### GPU Configuration (if needed)

```bash
ssh root@10.10.0.151 'bash /tmp/configure-plex-gpu.sh 220'
```

### Ansible Configuration (if needed)

```bash
cd infrastructure/ansible
ansible-playbook -i inventory/plex.yml playbooks/plex.yml
```

### Manual Backup

```bash
ssh root@10.10.0.60 /usr/local/bin/plex-backup.sh
```

### Restore from Backup

```bash
ssh root@10.10.0.60

# Stop Plex
docker compose -f /opt/plex/compose/docker-compose.yml stop

# Load Restic environment
source /etc/restic/plex.env

# List snapshots
restic snapshots

# Restore specific snapshot
restic restore <SNAPSHOT_ID> --target /opt/plex/config

# Start Plex
docker compose -f /opt/plex/compose/docker-compose.yml start
```

## Verification

### Hardware Transcoding

1. Play a video in Plex web UI
2. Force transcoding by lowering quality
3. Check Plex dashboard - should show "Video: Transcode (HW)"
4. Monitor GPU usage:

```bash
ssh root@10.10.0.60
apt install radeontop
radeontop
```

### NFS Mount

```bash
ssh root@10.10.0.60
mount | grep nfs
ls -la /mnt/media
```

### Backup Status

```bash
ssh root@10.10.0.60
systemctl status plex-backup.timer
systemctl list-timers plex-backup.timer
journalctl -u plex-backup.service -n 50
```

## Troubleshooting

### GPU Not Detected

```bash
# On Proxmox host
ssh root@10.10.0.151
lsmod | grep amdgpu
ls -la /dev/dri/

# Inside container
ssh root@10.10.0.60
ls -la /dev/dri/
cat /etc/pve/lxc/220.conf | grep dev
```

### Hardware Transcoding Not Working

```bash
ssh root@10.10.0.60

# Check Docker mod loaded
docker logs plex 2>&1 | grep -i vaapi

# Check VAAPI
vainfo --display drm --device /dev/dri/renderD128

# Check Plex transcoder settings
cat /opt/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml | grep -i hardware
```

### NFS Mount Issues

```bash
ssh root@10.10.0.60

# Test NFS connectivity
showmount -e 10.11.0.5

# Check routing to storage network
ip route get 10.11.0.5

# Test manual mount
mount -t nfs 10.11.0.5:/mnt/Tongariro/Plexopathy /mnt/test
```

### Backup Failures

```bash
ssh root@10.10.0.60

# Check logs
tail -f /var/log/plex-backup.log

# Test Restic manually
source /etc/restic/plex.env
restic snapshots
restic check
```

## Maintenance

### Update Plex

```bash
ssh root@10.10.0.60
cd /opt/plex/compose
docker compose pull
docker compose up -d
```

### View Logs

```bash
# Plex logs
ssh root@10.10.0.60 docker logs -f plex

# Backup logs
ssh root@10.10.0.60 tail -f /var/log/plex-backup.log
```

### Check Resource Usage

```bash
ssh root@10.10.0.151 pct status 220
ssh root@10.10.0.60 docker stats
```

## Destruction

To remove the Plex deployment:

```bash
cd infrastructure/terraform
terraform destroy -target=module.plex
```

## Integration Points

| Component | IP/Path | Purpose |
|-----------|---------|---------|
| Proxmox Host | 10.10.0.151 | "The Fal" |
| Plex Management | 10.10.0.60 | External access |
| Plex Storage | 10.11.0.60 | NFS to TrueNAS |
| TrueNAS NFS | 10.11.0.5 | Media source |
| MinIO Backups | 10.10.0.70:9000 | S3-compatible |
| Management Network | vmbr0 (10.10.0.0/24) | External access |
| Storage Network | vmbr1 (10.11.0.0/24) | NFS/Media traffic |

## File Structure

```
infrastructure/
├── terraform/
│   ├── modules/
│   │   └── plex-lxc/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── plex.tf
├── ansible/
│   ├── inventory/
│   │   └── plex.yml
│   ├── playbooks/
│   │   └── plex.yml
│   └── roles/
│       ├── plex/
│       │   ├── tasks/main.yml
│       │   ├── templates/
│       │   │   ├── docker-compose.yml.j2
│       │   │   ├── plex.env.j2
│       │   │   └── plex-backup.sh.j2
│       │   ├── handlers/main.yml
│       │   └── defaults/main.yml
│       └── restic/
│           ├── tasks/main.yml
│           └── templates/
│               ├── restic.env.j2
│               ├── plex-backup.service.j2
│               └── plex-backup.timer.j2
└── scripts/
    ├── configure-plex-gpu.sh
    └── verify-proxmox-gpu.sh
```
