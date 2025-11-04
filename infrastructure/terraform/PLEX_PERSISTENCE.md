# Plex Persistent Storage Strategies

## ⚠️ IMPORTANT: Data Persistence Across Proxmox Rebuilds

**Problem**: By default, the Plex configuration uses a local directory on the Proxmox host (`/var/lib/plex`). If the Proxmox host is rebuilt, **ALL Plex configuration and metadata will be LOST**.

**Solution**: Use network storage (NFS/SMB) or dedicated storage that survives host rebuilds.

---

## Storage Options

### Option 1: NFS Storage (RECOMMENDED) ✅

**Best for**: TrueNAS, Synology, QNAP, or any NFS server

**Advantages**:
- ✅ Survives Proxmox host rebuilds
- ✅ Can be backed up separately
- ✅ Accessible from multiple hosts
- ✅ Easy to migrate

**Configuration**:

```hcl
# terraform.tfvars
plex_lxc = {
  enabled       = true
  name          = "plex"
  ip            = "10.10.0.30"
  cores         = 4
  memory        = 4096
  disk          = 32
  gpu_pci_id    = "0000:00:00.0"

  # NFS configuration
  storage_type  = "nfs"
  storage_path  = "/mnt/plex-data"  # Mount point on Proxmox host
  nfs_server    = "10.10.0.50"      # Your NFS server IP
  nfs_path      = "/tank/plex"      # NFS export path
  nfs_options   = "vers=4,soft,timeo=600,retrans=2,rsize=1048576,wsize=1048576"

  # Optional: Add media library mounts
  media_mounts = [
    {
      type       = "nfs"
      source     = "/mnt/media"       # Mount on Proxmox host
      target     = "/media"           # Path in container
      read_only  = true
      nfs_server = "10.10.0.50"
      nfs_options = "vers=4,ro,soft"
    }
  ]
}
```

**Prerequisites**:
1. Set up NFS server (TrueNAS/NAS)
2. Create NFS export for Plex data
3. Ensure network connectivity from Proxmox to NFS server

**TrueNAS Setup Example**:
```bash
# On TrueNAS
# 1. Create dataset: /mnt/tank/plex
# 2. Share via NFS
# 3. Allow access from Proxmox IP: 10.10.0.151
# 4. Set permissions to allow read/write
```

---

### Option 2: SMB/CIFS Storage

**Best for**: Windows file shares, Samba servers

**Advantages**:
- ✅ Survives Proxmox host rebuilds
- ✅ Works with Windows servers
- ✅ Flexible authentication

**Configuration**:

```hcl
# terraform.tfvars
plex_lxc = {
  enabled       = true
  name          = "plex"
  ip            = "10.10.0.30"
  cores         = 4
  memory        = 4096
  disk          = 32
  gpu_pci_id    = "0000:00:00.0"

  # SMB configuration
  storage_type  = "smb"
  storage_path  = "/mnt/plex-data"
  smb_server    = "10.10.0.50"
  smb_share     = "plex"
  smb_username  = "plexuser"
  smb_password  = "SecurePassword123"
  smb_options   = "vers=3.0,rw,noperm"

  media_mounts = []
}
```

**Security Note**: SMB password is stored in Terraform state. Consider using Terraform Cloud or encrypted state storage.

---

### Option 3: Dedicated Storage Disk/Partition

**Best for**: Separate physical disk or partition on Proxmox host

**Advantages**:
- ✅ Can survive host rebuild if disk is separate
- ✅ Good performance
- ⚠️ Requires manual disk management during rebuilds

**Configuration**:

```bash
# On Proxmox host - one-time setup
# 1. Identify separate disk
lsblk

# 2. Format and mount (example with /dev/sdb1)
mkfs.ext4 /dev/sdb1
mkdir -p /mnt/plex-storage
mount /dev/sdb1 /mnt/plex-storage

# 3. Add to /etc/fstab for persistence
echo "UUID=$(blkid -s UUID -o value /dev/sdb1) /mnt/plex-storage ext4 defaults 0 2" >> /etc/fstab

# 4. Create Plex directory
mkdir -p /mnt/plex-storage/plex-data
```

```hcl
# terraform.tfvars
plex_lxc = {
  enabled       = true
  name          = "plex"
  ip            = "10.10.0.30"
  cores         = 4
  memory        = 4096
  disk          = 32
  gpu_pci_id    = "0000:00:00.0"

  storage_type  = "bind"
  storage_path  = "/mnt/plex-storage/plex-data"

  media_mounts = []
}
```

**Rebuild Instructions**: When rebuilding Proxmox, do NOT format the separate disk. Mount it to the same path and redeploy Terraform.

---

### Option 4: Local Storage (DEFAULT - NOT RECOMMENDED)

**Advantages**:
- ✅ Simple setup
- ✅ Good performance

**Disadvantages**:
- ❌ Data lost on Proxmox host rebuild
- ❌ No protection against host failure
- ❌ Difficult to migrate

**Configuration**:

```hcl
# terraform.tfvars (default)
plex_lxc = {
  enabled       = true
  name          = "plex"
  ip            = "10.10.0.30"
  cores         = 4
  memory        = 4096
  disk          = 32
  gpu_pci_id    = "0000:00:00.0"

  storage_type  = "local"
  storage_path  = "/var/lib/plex"

  media_mounts = []
}
```

**⚠️ WARNING**: This option means your Plex library, watch history, and settings will be lost if the Proxmox host fails or is rebuilt!

---

## Recommended Setup Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Proxmox Host (fal)                    │
│                                                           │
│  ┌────────────────────┐        ┌─────────────────────┐  │
│  │   Plex LXC (210)   │        │   NFS Client        │  │
│  │   10.10.0.30       │◄───────│  /mnt/plex-data     │  │
│  │                    │ bind   │  /mnt/media         │  │
│  │  /var/lib/plex ────┼────────┤                     │  │
│  │  /media ───────────┼────────┤                     │  │
│  └────────────────────┘        └─────────────────────┘  │
│                                          │               │
└──────────────────────────────────────────┼───────────────┘
                                           │ NFS
                        ┌──────────────────┴────────────┐
                        │  Network Storage (TrueNAS)    │
                        │  10.10.0.50                   │
                        │                               │
                        │  /tank/plex ← Config/Metadata │
                        │  /tank/media ← Movies/TV      │
                        └───────────────────────────────┘
```

---

## Backup Strategies

### Strategy 1: NFS Storage with ZFS Snapshots (RECOMMENDED)

If using TrueNAS or ZFS-based NFS:

```bash
# On TrueNAS/NFS server
# Set up automatic snapshots
zfs snapshot tank/plex@backup-$(date +%Y%m%d)

# Replicate to another location
zfs send tank/plex@backup-20250101 | ssh backup-server zfs recv backup/plex@20250101
```

### Strategy 2: Proxmox Backup

```bash
# Backup the container
vzdump 210 --mode stop --storage backup-storage

# Backup the bind-mounted storage separately
tar -czf /backup/plex-data-$(date +%Y%m%d).tar.gz /mnt/plex-data/
```

### Strategy 3: Plex Backup Scripts

Create automated backup inside container:

```bash
# Inside Plex container
cat > /usr/local/bin/plex-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d)

# Stop Plex
systemctl stop plexmediaserver

# Backup database and config
tar -czf "$BACKUP_DIR/plex-backup-$DATE.tar.gz" \
  "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server"

# Start Plex
systemctl start plexmediaserver

# Keep only last 7 backups
find "$BACKUP_DIR" -name "plex-backup-*.tar.gz" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/plex-backup.sh

# Add to cron (weekly backup)
echo "0 2 * * 0 /usr/local/bin/plex-backup.sh" | crontab -
```

---

## Disaster Recovery Procedures

### Scenario 1: Proxmox Host Rebuild (with NFS storage)

1. **Rebuild Proxmox**:
   ```bash
   # Install Proxmox on new/rebuilt host
   # Configure networking (same IPs: 10.10.0.151)
   ```

2. **Restore Terraform State**:
   ```bash
   cd infrastructure/terraform
   terraform init
   ```

3. **Redeploy Plex**:
   ```bash
   terraform apply
   # NFS mount will reconnect automatically
   # All Plex data preserved!
   ```

4. **Verify**:
   ```bash
   ssh root@10.10.0.151
   pct enter 210
   ls -la /var/lib/plexmediaserver/
   systemctl status plexmediaserver
   ```

### Scenario 2: Proxmox Host Rebuild (with local storage)

**YOU WILL LOSE ALL DATA** - Restore from backup:

1. Rebuild Proxmox and redeploy Plex LXC
2. Stop Plex service
3. Restore backup:
   ```bash
   pct enter 210
   systemctl stop plexmediaserver
   cd /var/lib/plexmediaserver
   tar -xzf /path/to/plex-backup-YYYYMMDD.tar.gz
   chown -R plex:plex /var/lib/plexmediaserver
   systemctl start plexmediaserver
   ```

### Scenario 3: Migration to New Proxmox Host

With NFS storage:

1. **On old host**: Document NFS configuration
2. **On new host**:
   ```bash
   # Install Proxmox
   # Configure same network settings
   # Install NFS client: apt install nfs-common
   ```
3. **Deploy with Terraform**:
   ```bash
   terraform init
   terraform apply -target=proxmox_virtual_environment_container.plex
   ```
4. NFS mounts connect to same storage - **zero data loss**!

---

## Testing Your Persistence Setup

### Test 1: Container Recreation

```bash
# Destroy and recreate container
cd infrastructure/terraform
terraform destroy -target=proxmox_virtual_environment_container.plex
terraform apply -target=proxmox_virtual_environment_container.plex

# Verify data is still present
pct enter 210
ls -la /var/lib/plexmediaserver/Library/Application\ Support/Plex\ Media\ Server/
```

If data is gone, **your storage is NOT persistent**!

### Test 2: Host Reboot

```bash
# Reboot Proxmox host
ssh root@10.10.0.151 reboot

# After reboot, check mounts
ssh root@10.10.0.151
mount | grep plex
pct status 210
pct enter 210
```

Storage should automatically remount.

### Test 3: Network Storage Availability

```bash
# On Proxmox host
showmount -e 10.10.0.50  # Check NFS exports
mount | grep nfs          # Verify mounts
df -h /mnt/plex-data      # Check available space
```

---

## Performance Considerations

### NFS Performance Tuning

```hcl
nfs_options = "vers=4,soft,timeo=600,retrans=2,rsize=1048576,wsize=1048576,async,noatime"
```

**Options explained**:
- `vers=4` - Use NFSv4 (better performance)
- `soft` - Return error if server unavailable (vs hard which hangs)
- `rsize=1048576` - 1MB read size
- `wsize=1048576` - 1MB write size
- `async` - Faster writes (less safe)
- `noatime` - Don't update access times (faster)

### SMB Performance Tuning

```hcl
smb_options = "vers=3.11,rw,noperm,cache=strict,actimeo=60"
```

### Monitor Storage Performance

```bash
# Inside Plex container
apt install -y iotop
iotop  # Monitor disk I/O

# Test write speed
dd if=/dev/zero of=/var/lib/plexmediaserver/test bs=1M count=1024
# Test read speed
dd if=/var/lib/plexmediaserver/test of=/dev/null bs=1M
rm /var/lib/plexmediaserver/test
```

---

## Recommended Configuration Summary

### For Production (BEST):
```hcl
storage_type = "nfs"
nfs_server   = "10.10.0.50"  # Your TrueNAS/NAS IP
nfs_path     = "/tank/plex"
```

### For Testing/Development:
```hcl
storage_type = "local"
storage_path = "/var/lib/plex"
```

### For Separate Physical Disk:
```hcl
storage_type = "bind"
storage_path = "/mnt/plex-storage/plex-data"
```

---

## Troubleshooting

### NFS Mount Fails

```bash
# On Proxmox host
showmount -e 10.10.0.50  # Check exports
mount -t nfs 10.10.0.50:/tank/plex /mnt/test  # Manual test

# Check firewall
iptables -L -n | grep 2049

# Check NFS logs
journalctl -u nfs-common -f
```

### SMB Mount Fails

```bash
# Test SMB connection
smbclient -L //10.10.0.50 -U plexuser

# Mount manually
mount -t cifs //10.10.0.50/plex /mnt/test -o username=plexuser,password=pass

# Check logs
journalctl | grep cifs
```

### Permission Issues

```bash
# On NFS server (TrueNAS)
# Set ownership to nobody:nogroup or specific UID/GID
# Match container's plex user UID (usually 998)

# In container
id plex  # Check UID

# On NFS server
chown -R 998:998 /tank/plex
```

---

## Migration Checklist

When migrating to persistent storage:

- [ ] Set up NFS/SMB server
- [ ] Test network connectivity
- [ ] Test mount manually on Proxmox host
- [ ] Update terraform.tfvars with storage config
- [ ] Run `terraform plan` to review changes
- [ ] Backup existing Plex data (if any)
- [ ] Run `terraform apply`
- [ ] Verify mounts in container: `pct enter 210` → `df -h`
- [ ] Copy existing Plex data to new storage (if applicable)
- [ ] Test Plex functionality
- [ ] Set up automated backups
- [ ] Document recovery procedure

---

## Questions?

**Q: Can I change storage type after initial deployment?**
A: Yes, but you'll need to migrate data manually:
1. Backup current Plex data
2. Update terraform.tfvars
3. Run `terraform apply`
4. Restore data to new storage location

**Q: What happens if NFS server goes down?**
A: Plex will fail to read/write data. Container remains running but functionality is limited. Use `soft` mount option to prevent hangs.

**Q: Can I use multiple storage backends?**
A: Yes! Main config on NFS, media on SMB:
```hcl
storage_type = "nfs"  # For config
media_mounts = [{
  type = "smb"  # For media
  source = "//server/movies"
}]
```

**Q: Is local storage really that bad?**
A: For testing: fine. For production: **avoid**. You WILL lose data eventually.
