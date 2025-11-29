# ==============================================================================
# Plex Media Server - Docker in LXC Container with Intel GPU Passthrough
# ==============================================================================

module "plex_lxc" {
  source = "./modules/plex-lxc"

  container_name       = "plex-media-server"
  container_id         = 250
  target_node          = var.proxmox_node
  ip_address           = "10.10.0.60"
  gateway              = var.prod_gateway
  dns_servers          = var.dns_servers
  network_bridge       = var.network_bridge
  storage              = var.proxmox_storage
  memory               = 8192
  cores                = 4
  disk_size            = 50

  plex_root_password   = var.plex_root_password
  plex_claim_token     = var.plex_claim_token
  ssh_public_keys      = var.ssh_public_keys

  proxmox_host         = var.proxmox_host
  proxmox_user         = var.proxmox_user
  proxmox_password     = var.proxmox_password

  truenas_ip           = "10.20.0.100"
  truenas_nfs_paths = {
    media = {
      source = "10.20.0.100:/mnt/Tongariro/Plexopathy/media"
      target = "/mnt/media"
    }
  }
}

# Configure Restic backup for Plex configuration
module "plex_backup" {
  depends_on = [module.plex_lxc]
  source     = "./modules/restic-backup"

  host                = "10.10.0.60"
  host_user          = "root"
  host_password      = var.plex_root_password
  ssh_key_path       = null
  container_name     = "plex-restic-backup"

  restic_repository   = "s3:http://10.20.0.100:9000/restic-backups/plex"
  restic_password     = var.restic_encryption_password
  aws_access_key      = var.minio_access_key
  aws_secret_key      = var.minio_secret_key

  backup_paths = ["/opt/plex/config"]
  backup_excludes = [
    ".cache",
    "*.tmp",
    "Library/Preferences/com.plexapp.plugins*",
  ]

  schedule_hour   = 3
  schedule_minute = 0
  retention_daily = 7
  retention_weekly = 4
  retention_monthly = 12
}
