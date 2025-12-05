# Plex Deployment - Step-by-Step Guide

## Current Status
✅ **Container Created** - Plex LXC (ID: 220) is running
⏳ **GPU Configuration** - Needs to be applied
⏳ **Ansible Provisioning** - Needs to be run

---

## Step 1: Verify Prerequisites (5 minutes)

### Option A: If you have SSH access to Proxmox host

```bash
ssh root@10.10.0.151 'bash -s' < scripts/maintenance/verify-proxmox-gpu.sh
```

### Option B: Manual verification on Proxmox host

SSH to Proxmox and run:

```bash
# Check IOMMU
grep iommu=pt /proc/cmdline

# Check AMD GPU driver
lsmod | grep amdgpu

# Check DRI devices
ls -la /dev/dri/
# Should see: renderD128

# Check render group
stat -c '%g' /dev/dri/renderD128
# Should return a GID (usually 104 or 106)
```

**Expected Output**: All checks should pass with ✓

---

## Step 2: Configure GPU Passthrough (2 minutes)

### Method 1: Automated (if you have SSH access)

```bash
# From your workstation
scp scripts/maintenance/configure-plex-gpu.sh root@10.10.0.151:/tmp/
ssh root@10.10.0.151 'bash /tmp/configure-plex-gpu.sh 220'
```

### Method 2: Manual (if no SSH access)

1. SSH to Proxmox host:
   ```bash
   ssh root@10.10.0.151
   ```

2. Stop the container:
   ```bash
   pct stop 220
   ```

3. Get render device GID:
   ```bash
   RENDER_GID=$(stat -c '%g' /dev/dri/renderD128)
   echo "Render GID: $RENDER_GID"
   ```

4. Edit container config:
   ```bash
   nano /etc/pve/lxc/220.conf
   ```

5. Add these lines at the end:
   ```
   # AMD 680M GPU Passthrough for VAAPI transcoding
   dev0: /dev/dri/card0,gid=<RENDER_GID>,mode=0666
   dev1: /dev/dri/renderD128,gid=<RENDER_GID>,mode=0666

   # cgroup device access
   lxc.cgroup2.devices.allow: c 226:* rwm

   # Mount DRI devices
   lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
   ```
   (Replace `<RENDER_GID>` with the actual GID from step 3)

6. Start the container:
   ```bash
   pct start 220
   ```

7. Verify GPU access:
   ```bash
   pct exec 220 -- ls -la /dev/dri/
   ```
   Should see `card0` and `renderD128`

---

## Step 3: Get Plex Claim Token (Optional, 2 minutes)

### Do You Need It?

**Skip this if:**
- You want to claim the server manually through the web UI later
- You're just testing

**Get it if:**
- You want automatic server claiming during setup
- You want to save a manual step

### How to Get It

1. **Open**: https://www.plex.tv/claim/
2. **Sign in** with your Plex account
3. **Copy** the token (starts with `claim-`)
4. **Important**: Token expires in 4 minutes!

**Save it temporarily:**
```bash
export PLEX_CLAIM="claim-your-token-here"
```

---

## Step 4: Set Environment Variables (1 minute)

### Required for Restic Backups

You need to set these before running Ansible:

```bash
# Restic backup password (create a strong password)
export RESTIC_PASSWORD="your-secure-password-here"

# MinIO credentials (for S3 backup storage)
export MINIO_ACCESS_KEY="your-minio-access-key"
export MINIO_SECRET_KEY="your-minio-secret-key"

# Plex claim token (optional - skip if you want to claim manually)
export PLEX_CLAIM="claim-xxxxxxxxxxxxxxxxxxxx"
```

### Don't Have MinIO Credentials?

If you don't have MinIO set up yet, you can:

**Option A**: Skip backups for now (comment out the restic role in playbook)
```bash
# Edit the playbook
nano infrastructure/ansible/playbooks/plex.yml

# Comment out this line:
#    - role: restic
```

**Option B**: Use placeholder values and set up backups later
```bash
export RESTIC_PASSWORD="changeme"
export MINIO_ACCESS_KEY="changeme"
export MINIO_SECRET_KEY="changeme"
```

---

## Step 5: Run Ansible Provisioning (10-15 minutes)

```bash
# Navigate to ansible directory
cd /root/homelab-test/infrastructure/ansible

# Run the playbook
ansible-playbook -i inventory/plex.yml playbooks/plex.yml
```

### What Ansible Will Do

1. ✅ Install Docker and required packages
2. ✅ Verify GPU access (vainfo check)
3. ✅ Mount TrueNAS NFS share to `/mnt/media`
4. ✅ Deploy Plex via Docker Compose
5. ✅ Configure Restic backups (if credentials provided)
6. ✅ Wait for Plex to be ready

### Expected Output

You should see:
```
PLAY RECAP *****************************************************
plex: ok=XX changed=XX unreachable=0 failed=0
```

---

## Step 6: Access Plex (2 minutes)

### Open Web UI

**URL**: http://10.10.0.60:32400/web

### Initial Setup

1. **Sign in** with your Plex account
   - If you provided `PLEX_CLAIM` token, it's already linked!
   - If not, you'll need to claim the server now

2. **Add Library**:
   - Click "Add Library"
   - Choose library type (Movies, TV Shows, etc.)
   - Browse to `/data` (this is your TrueNAS NFS mount)
   - Select your media folders

3. **Enable Hardware Transcoding**:
   - Settings → Server → Transcoder
   - ✅ Check "Use hardware acceleration when available"
   - Save

---

## Step 7: Verify Hardware Transcoding (5 minutes)

### Test GPU Transcoding

1. **Play a video** in Plex web UI
2. **Lower the quality** to force transcoding:
   - Click the settings icon during playback
   - Select a lower quality (e.g., 720p 2Mbps)

3. **Check Dashboard**:
   - Go to Plex → Dashboard
   - Should show: **"Video: Transcode (HW)"**
   - If it says "(hw)", GPU is working!

### Monitor GPU Usage

```bash
# SSH to Plex container
ssh root@10.10.0.60

# Install monitoring tool
apt update && apt install radeontop -y

# Monitor GPU
radeontop
```

During transcoding, you should see GPU activity.

---

## Quick Command Reference

### Check Container Status
```bash
ssh root@10.10.0.151 pct status 220
```

### Check GPU Devices
```bash
ssh root@10.10.0.60 ls -la /dev/dri/
```

### Check VAAPI Support
```bash
ssh root@10.10.0.60 vainfo --display drm --device /dev/dri/renderD128
```

### Check Plex Status
```bash
ssh root@10.10.0.60 docker ps
ssh root@10.10.0.60 docker logs plex
```

### Check NFS Mount
```bash
ssh root@10.10.0.60 mount | grep nfs
ssh root@10.10.0.60 ls -la /mnt/media
```

### Restart Plex
```bash
ssh root@10.10.0.60
cd /opt/plex/compose
docker compose restart
```

### Check Backup Timer
```bash
ssh root@10.10.0.60 systemctl status plex-backup.timer
ssh root@10.10.0.60 systemctl list-timers
```

---

## Troubleshooting

### GPU Not Detected

**Problem**: vainfo fails or /dev/dri/ is empty

**Solution**:
```bash
# On Proxmox host, check GPU config
ssh root@10.10.0.151 cat /etc/pve/lxc/220.conf | grep dev

# Verify devices exist on host
ssh root@10.10.0.151 ls -la /dev/dri/

# Restart container
ssh root@10.10.0.151 pct restart 220
```

### NFS Mount Fails

**Problem**: /mnt/media is empty or mount failed

**Solution**:
```bash
# SSH to container
ssh root@10.10.0.60

# Check if TrueNAS is reachable
ping -c 3 10.11.0.5

# Test NFS manually
showmount -e 10.11.0.5

# Check routing to storage network
ip route get 10.11.0.5
```

### Plex Won't Start

**Problem**: Docker container won't start

**Solution**:
```bash
ssh root@10.10.0.60
cd /opt/plex/compose

# Check logs
docker logs plex

# Restart
docker compose restart

# Rebuild if needed
docker compose down
docker compose up -d
```

### Hardware Transcoding Not Working

**Problem**: Shows "Transcode (sw)" instead of "(hw)"

**Solution**:
```bash
# Check VAAPI support
ssh root@10.10.0.60 vainfo --display drm --device /dev/dri/renderD128

# Check Plex logs for GPU errors
ssh root@10.10.0.60 docker logs plex 2>&1 | grep -i vaapi

# Verify transcoder settings in Plex
# Settings → Transcoder → Use hardware acceleration
```

---

## Summary Checklist

- [ ] Prerequisites verified (IOMMU, GPU driver, /dev/dri/)
- [ ] GPU passthrough configured in LXC
- [ ] Environment variables set
- [ ] Ansible playbook executed successfully
- [ ] Plex accessible at http://10.10.0.60:32400/web
- [ ] Library added pointing to /data
- [ ] Hardware transcoding enabled
- [ ] GPU transcoding verified with test video

---

## What's Next?

Once everything is working:

1. **Add More Libraries**: Movies, TV Shows, Music, etc.
2. **Configure Remote Access**: Settings → Remote Access
3. **Set Up Users**: Share with family/friends
4. **Optimize Transcoding**: Settings → Transcoder (bitrates, quality)
5. **Monitor Backups**: Check `/var/log/plex-backup.log`

## Support

- **Detailed docs**: `/root/homelab-test/docs/PLEX_DEPLOYMENT.md`
- **Quick reference**: `/root/homelab-test/docs/PLEX_QUICK_START.md`
- **Scripts**: `/root/homelab-test/scripts/maintenance/`
