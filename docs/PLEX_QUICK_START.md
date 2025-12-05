# Plex LXC Quick Start Guide

## Overview

Deploy Plex Media Server in an LXC container with AMD 680M GPU hardware transcoding.

## Prerequisites Check

```bash
# Verify Proxmox host GPU prerequisites
ssh root@10.10.0.151 'bash -s' < scripts/maintenance/verify-proxmox-gpu.sh
```

## Deployment (3 Steps)

### 1. Set Environment Variables

```bash
export RESTIC_PASSWORD="your-secure-password"
export MINIO_ACCESS_KEY="your-minio-access-key"
export MINIO_SECRET_KEY="your-minio-secret-key"
export PLEX_CLAIM="claim-xxxxxxxxxxxxx"  # Optional - get from plex.tv/claim
```

### 2. Deploy with Terraform

```bash
cd infrastructure/terraform
terraform init
terraform apply -target=module.plex
```

This will:
- ✅ Create LXC container (ID: 220)
- ✅ Configure AMD 680M GPU passthrough
- ✅ Install Docker and Plex
- ✅ Mount TrueNAS NFS media
- ✅ Configure Restic backups

### 3. Access Plex

Open in browser: **http://10.10.0.60:32400/web**

## Post-Deployment Configuration

1. **Sign in** with your Plex account
2. **Add library** pointing to `/data`
3. **Enable Hardware Transcoding**:
   - Settings → Transcoder
   - ✅ Use hardware acceleration when available

## Verification Commands

```bash
# Container status
ssh root@10.10.0.151 pct status 220

# GPU access
ssh root@10.10.0.60 ls -la /dev/dri/

# VAAPI support
ssh root@10.10.0.60 vainfo --display drm --device /dev/dri/renderD128

# Plex status
curl -I http://10.10.0.60:32400/web

# Media mount
ssh root@10.10.0.60 mount | grep nfs

# Backup timer
ssh root@10.10.0.60 systemctl status plex-backup.timer
```

## Hardware Transcoding Test

1. Play a video in Plex
2. Lower quality to force transcoding
3. Check dashboard shows: **"Video: Transcode (HW)"**
4. Monitor GPU usage:

```bash
ssh root@10.10.0.60
apt install radeontop
radeontop
```

## Manual Operations

### Manual GPU Configuration

```bash
ssh root@10.10.0.151 'bash /tmp/configure-plex-gpu.sh 220'
```

### Manual Ansible Configuration

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
docker compose -f /opt/plex/compose/docker-compose.yml stop
source /etc/restic/plex.env
restic snapshots
restic restore <SNAPSHOT_ID> --target /opt/plex/config
docker compose -f /opt/plex/compose/docker-compose.yml start
```

## Troubleshooting

### GPU Not Working

```bash
# Check Proxmox host
ssh root@10.10.0.151 lsmod | grep amdgpu
ssh root@10.10.0.151 ls -la /dev/dri/

# Check container
ssh root@10.10.0.60 ls -la /dev/dri/
ssh root@10.10.0.60 vainfo --display drm --device /dev/dri/renderD128
```

### NFS Mount Issues

```bash
ssh root@10.10.0.60
showmount -e 10.11.0.5
ip route get 10.11.0.5
mount | grep nfs
```

### Plex Not Starting

```bash
ssh root@10.10.0.60
docker logs plex
docker compose -f /opt/plex/compose/docker-compose.yml restart
```

## Container Specifications

| Setting | Value |
|---------|-------|
| VM ID | 220 |
| Hostname | plex |
| Management IP | 10.10.0.60 (vmbr0) |
| Storage IP | 10.11.0.60 (vmbr1) |
| CPUs | 4 cores |
| RAM | 8GB |
| Disk | 100GB |
| Type | Privileged LXC |
| GPU | AMD Radeon 680M (VAAPI) |

## Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Plex LXC Container (ID: 220)                            │
│                                                         │
│  Management NIC (eth0)          Storage NIC (eth1)     │
│  10.10.0.60 ─────────────────────── 10.11.0.60        │
│       │                                   │            │
└───────┼───────────────────────────────────┼────────────┘
        │                                   │
        │ vmbr0                             │ vmbr1
        │                                   │
   [Internet/LAN]                    [TrueNAS NFS]
   Plex Web UI                       10.11.0.5
   Homepage                          /mnt/Tongariro/Plexopathy
```

## Backup Schedule

- **Frequency**: Daily at 03:00
- **Retention**: 7 daily, 4 weekly, 12 monthly
- **Target**: MinIO S3 (10.10.0.70:9000/plex-backups)
- **What**: Plex database, metadata, configurations
- **Excluded**: Cache, logs, updates

## Update Plex

```bash
ssh root@10.10.0.60
cd /opt/plex/compose
docker compose pull
docker compose up -d
```

## Destruction

```bash
cd infrastructure/terraform
terraform destroy -target=module.plex
```

## Support

See detailed documentation: [PLEX_DEPLOYMENT.md](PLEX_DEPLOYMENT.md)
