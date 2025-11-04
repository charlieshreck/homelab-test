# Plex Media Server LXC Setup Guide

## Overview

This Terraform configuration deploys a Plex Media Server in a Debian 12 LXC container with:
- **AMD Radeon 680M GPU** hardware transcoding support
- **Persistent storage** for configuration and metadata
- **Cloud-init** automated installation of the latest Plex version
- **Privileged container** for GPU passthrough

## Architecture

- **Container ID**: 210
- **IP Address**: 10.10.0.30/24
- **Gateway**: 10.10.0.1
- **Resources**: 4 CPU cores, 4GB RAM, 32GB disk
- **Storage**: `/var/lib/plex` on Proxmox host for persistent data
- **Network**: vmbr0 (management network)

## Prerequisites

### 1. Proxmox Host GPU Setup

Ensure AMD GPU drivers are loaded on the Proxmox host:

```bash
# SSH into Proxmox host
ssh root@10.10.0.151

# Check if GPU is detected
lspci | grep -i vga
lspci | grep -i amd

# Verify /dev/dri devices exist
ls -la /dev/dri/
# Expected output: card0, renderD128, controlD64

# Check GPU info
lshw -C display

# Load AMD GPU modules if not already loaded
modprobe amdgpu
```

### 2. Enable IOMMU (if not already enabled)

Edit `/etc/default/grub` on Proxmox host:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt video=efifb:off"
```

Update GRUB and reboot:

```bash
update-grub
reboot
```

### 3. Create Storage Directory

Create the persistent storage directory on the Proxmox host:

```bash
ssh root@10.10.0.151
mkdir -p /var/lib/plex
chmod 755 /var/lib/plex
```

## Deployment

### 1. Deploy with Terraform

```bash
cd /home/user/homelab-test/infrastructure/terraform

# Initialize (if first time)
terraform init

# Plan to see what will be created
terraform plan

# Apply the configuration
terraform apply
```

### 2. Monitor Container Creation

The container will:
1. Download Debian 12 LXC template (~5 minutes)
2. Create container with GPU passthrough
3. Run cloud-init to install Plex (~10 minutes)
4. Start Plex Media Server automatically

Check container status:

```bash
# On Proxmox host
pct status 210
pct config 210

# View container console
pct enter 210

# Check Plex installation log
tail -f /var/log/cloud-init-output.log

# Verify GPU access
ls -la /dev/dri/
vainfo
```

## Post-Deployment Setup

### 1. Initial Plex Configuration

1. **Get claim token** from https://plex.tv/claim (valid for 4 minutes)

2. **Access Plex web interface**:
   ```
   http://10.10.0.30:32400/web
   ```

3. **Complete initial setup**:
   - Sign in with Plex account
   - Name your server
   - Add media libraries

### 2. Verify GPU Transcoding

1. Access Plex settings: **Settings → Transcoder**

2. Enable hardware transcoding:
   - **Use hardware acceleration when available**: ✓ Enabled
   - **Hardware transcoding device**: Should detect AMD GPU

3. Check transcoding logs:
   ```bash
   # Inside container
   tail -f "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Logs/Plex Media Server.log"
   ```

4. Test with a video that requires transcoding and check for:
   ```
   [Transcoder] [VAAPI] Hardware transcoding enabled
   ```

### 3. GPU Status Check

Check GPU detection inside container:

```bash
pct enter 210

# Check GPU devices
ls -la /dev/dri/
# Expected: card0, renderD128, controlD64

# Check VA-API support
vainfo
# Should show AMD GPU capabilities

# Check GPU usage during transcoding
radeontop
```

### 4. Add Media Storage (Optional)

To add network shares or additional storage:

1. **Edit terraform.tfvars**:
   ```hcl
   plex_lxc = {
     # ... existing config ...
     media_paths = [
       {
         source = "/mnt/media"      # Path on Proxmox host
         target = "/media"           # Path in container
         read_only = true
       }
     ]
   }
   ```

2. **Or manually mount via Proxmox**:
   ```bash
   pct set 210 -mp1 /mnt/media,mp=/media,ro=1
   ```

## Troubleshooting

### GPU Not Detected in Container

```bash
# On Proxmox host, check GPU devices
ls -la /dev/dri/

# Verify container config
cat /etc/pve/lxc/210.conf | grep -E "(cgroup2|mount.entry)"

# Should see lines like:
# lxc.cgroup2.devices.allow: c 226:0 rwm
# lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file

# Restart container
pct stop 210
pct start 210
```

### Plex Not Starting

```bash
# Check cloud-init logs
pct enter 210
tail -f /var/log/cloud-init-output.log

# Check Plex service status
systemctl status plexmediaserver

# Check Plex logs
tail -f "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Logs/Plex Media Server.log"

# Manually restart Plex
systemctl restart plexmediaserver
```

### Transcoding Not Using GPU

1. **Check Plex settings**: Settings → Transcoder → Hardware acceleration
2. **Verify GPU permissions**:
   ```bash
   ls -la /dev/dri/
   # Should be accessible by plex user
   groups plex
   # Should include: video, render
   ```
3. **Check kernel logs**:
   ```bash
   dmesg | grep -i amdgpu
   dmesg | grep -i drm
   ```

### Network Issues

```bash
# Inside container
ip addr show
ping 10.10.0.1
ping 8.8.8.8

# On Proxmox host
ip route
iptables -L -n -v
```

## Updating Plex

### Automatic Updates
Plex checks for updates automatically. Enable in:
**Settings → General → Update automatically**

### Manual Update
```bash
pct enter 210

cd /tmp
PLEX_URL=$(curl -s 'https://plex.tv/api/downloads/5.json' | grep -oP '"linux".*?"url":\s*"\K[^"]+' | grep 'amd64.deb' | head -n 1)
wget -O plexmediaserver.deb "$PLEX_URL"
dpkg -i plexmediaserver.deb
systemctl restart plexmediaserver
```

## Backup and Restore

### Backup Plex Configuration

```bash
# On Proxmox host
tar -czf /root/plex-backup-$(date +%Y%m%d).tar.gz /var/lib/plex/

# Or use Proxmox backup
vzdump 210 --mode stop --compress zstd --storage local
```

### Restore

```bash
# Stop container
pct stop 210

# Restore data
cd /var/lib/plex
tar -xzf /root/plex-backup-YYYYMMDD.tar.gz --strip-components=3

# Start container
pct start 210
```

## Performance Tuning

### Increase Transcoder Performance

1. **Adjust CPU priority** (in terraform.tfvars):
   ```hcl
   plex_lxc = {
     cores = 6  # Increase cores if available
     memory = 8192  # Increase to 8GB for large libraries
   }
   ```

2. **Optimize Plex transcoder**:
   - Settings → Transcoder
   - **Transcoder temporary directory**: /tmp (uses RAM)
   - **Background transcoding x264 preset**: fast or veryfast
   - **Maximum simultaneous video transcode**: Based on GPU capability

## Security Considerations

1. **Change default password**:
   ```bash
   pct enter 210
   passwd
   ```

2. **Restrict network access** (optional):
   - Use Proxmox firewall rules
   - Limit access to trusted networks

3. **Regular updates**:
   ```bash
   pct enter 210
   apt update && apt upgrade -y
   ```

## Monitoring

### Resource Usage

```bash
# On Proxmox host
pct status 210
pct config 210

# Inside container
htop
iostat
vmstat
```

### Plex Statistics

Access in Plex: **Settings → Status → Dashboard**
- Active streams
- Transcoding sessions
- GPU usage

## Useful Commands

```bash
# Container management
pct start 210
pct stop 210
pct restart 210
pct enter 210

# View logs
pct exec 210 -- journalctl -u plexmediaserver -f

# Resource stats
pct status 210
pveperf

# Network test
pct exec 210 -- curl -I http://plex.tv
```

## Configuration Reference

### Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enabled` | `true` | Enable/disable Plex LXC |
| `name` | `plex` | Container hostname |
| `ip` | `10.10.0.30` | Static IP address |
| `cores` | `4` | CPU cores |
| `memory` | `4096` | RAM in MB |
| `disk` | `32` | Root disk size in GB |
| `gpu_pci_id` | Auto-detected | GPU PCI ID (not used with /dev/dri passthrough) |
| `storage_path` | `/var/lib/plex` | Persistent storage path on Proxmox host |

### Plex Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 32400 | TCP | Plex Web UI / API |
| 1900 | UDP | DLNA discovery |
| 3005 | TCP | Plex Companion |
| 5353 | UDP | Bonjour/Avahi |
| 8324 | TCP | Plex for Roku |
| 32410-32414 | UDP | GDM network discovery |

## Additional Resources

- [Plex Media Server Documentation](https://support.plex.tv/)
- [Hardware Transcoding Requirements](https://support.plex.tv/articles/115002178853-using-hardware-accelerated-streaming/)
- [LXC GPU Passthrough Guide](https://pve.proxmox.com/wiki/Linux_Container#_bind_mount_points)
- [AMD GPU on Linux](https://wiki.archlinux.org/title/AMDGPU)

## Support

For issues with:
- **Plex**: https://forums.plex.tv/
- **Proxmox LXC**: https://forum.proxmox.com/
- **This configuration**: Check logs and troubleshooting section above
