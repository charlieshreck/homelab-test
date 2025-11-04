# terraform.tfvars - Production setup for "the fal" with 3 workers and Mayastor

# Proxmox Connection - The Fal
proxmox_host     = "10.10.0.151"
proxmox_user     = "root@pam"
proxmox_password = "H4ckwh1z"
proxmox_node     = "fal"

# Networks
# Primary network for management and general traffic
prod_gateway     = "10.10.0.1"
network_bridge   = "vmbr0"

# Storage network for Mayastor and TrueNAS
storage_gateway     = "10.11.0.1"
storage_bridge      = "vmbr1"

# Cluster
cluster_name       = "homelab-test"
talos_version      = "v1.11.3"
kubernetes_version = "v1.34.1"

# Storage
# 140GB local-lvm for VMs, 1TB helford for Mayastor
proxmox_storage          = "local-lvm"
proxmox_mayastor_storage = "helford"
proxmox_iso_storage      = "local"

# VM ID Management
vm_id_start = 200

# Control Plane
# Ryzen 9 6800HX with 32GB total RAM
control_plane = {
  name   = "talos-cp-01"
  ip     = "10.10.0.20"
  cores  = 2
  memory = 4096
  disk   = 30
}

# Workers with dual vNICs (management + storage network)
# Total: 3 workers for Mayastor (minimum requirement)
# ~9GB RAM per worker from 32GB total (leaving ~5GB for Proxmox + CP)
workers = {
  "worker-01" = {
    name          = "talos-worker-01"
    ip            = "10.10.0.21"
    storage_ip    = "10.11.0.21"
    cores         = 4  # Increased from 2 to support Mayastor IO engine (2 cores) + workloads
    memory        = 9216
    disk          = 30
    gpu           = false
    gpu_pci_id    = null
    mayastor_disk = 300
  }
  "worker-02" = {
    name          = "talos-worker-02"
    ip            = "10.10.0.22"
    storage_ip    = "10.11.0.22"
    cores         = 4  # Increased from 2 to support Mayastor IO engine (2 cores) + workloads
    memory        = 9216
    disk          = 30
    gpu           = false
    gpu_pci_id    = null
    mayastor_disk = 300
  }
  "worker-03" = {
    name          = "talos-worker-03"
    ip            = "10.10.0.23"
    storage_ip    = "10.11.0.23"
    cores         = 4  # Increased from 2 to support Mayastor IO engine (2 cores) + workloads
    memory        = 9216
    disk          = 30
    gpu           = false
    gpu_pci_id    = null
    mayastor_disk = 300
  }
}

# Storage Nodes (not needed - using workers for Mayastor)
storage_nodes = {}


# GitOps Configuration
gitops_repo_url    = "https://github.com/charlieshreck/homelab-test.git"
gitops_repo_branch = "main"

# Cilium LoadBalancer Configuration
# Using Cilium's native LB instead of MetalLB
cilium_lb_ip_pool = ["10.10.0.50-10.10.0.99"]

# Cloudflare Configuration
cloudflare_email     = "charlieshreck@gmail.com"
cloudflare_domain    = "shreck.co.uk"

# Infisical Configuration
infisical_client_id     = "26428618-6807-4a12-a461-33242ec1af50"
infisical_client_secret = "8176c36e0e932f660327236ad288cfb1edbbced739d9c2d074d8cedabf492ee3"

# Docker Hub Configuration (to avoid rate limiting)
dockerhub_username = "mrlong67"
dockerhub_password = "B@yc3*rRR483EZDVBNqa9!5uFSjz8I&Om8YW#tuA0S2%X*k1#yUnEJsw$4*t$iqF%QJsQ7Q02$&97A$OeYiYn&fjy0nUPV856Q7j8x5INTQ77rQ!P*74*xLp^pJ#0tsn"

# Plex Media Server LXC Configuration
# AMD Radeon 680M iGPU in Ryzen 9 6800HX for hardware transcoding
#
# ⚠️ IMPORTANT: Current config uses LOCAL storage which is NOT persistent
# across Proxmox host rebuilds. See PLEX_PERSISTENCE.md for alternatives.
#
# For production use, configure NFS or SMB storage (see examples below)

# DEFAULT CONFIGURATION (LOCAL STORAGE - NOT PERSISTENT)
plex_lxc = {
  enabled       = true
  name          = "plex"
  ip            = "10.10.0.30"
  cores         = 4
  memory        = 4096  # 4GB RAM for Plex
  disk          = 32    # 32GB for OS and Plex application
  gpu_pci_id    = "0000:00:00.0"  # Auto-detected via /dev/dri passthrough

  # Local storage - data lost on host rebuild!
  storage_type  = "local"
  storage_path  = "/var/lib/plex"

  # NFS settings (not used with storage_type="local")
  nfs_server    = null
  nfs_path      = null
  nfs_options   = "vers=4,soft,timeo=600,retrans=2,rsize=1048576,wsize=1048576"

  # SMB settings (not used with storage_type="local")
  smb_server    = null
  smb_share     = null
  smb_username  = null
  smb_password  = null
  smb_options   = "vers=3.0,rw,noperm"

  # Media library mounts (optional)
  media_mounts  = []
}

# EXAMPLE: NFS CONFIGURATION (RECOMMENDED FOR PRODUCTION)
# Uncomment and modify to use persistent NFS storage
# plex_lxc = {
#   enabled       = true
#   name          = "plex"
#   ip            = "10.10.0.30"
#   cores         = 4
#   memory        = 4096
#   disk          = 32
#   gpu_pci_id    = "0000:00:00.0"
#
#   # NFS storage configuration
#   storage_type  = "nfs"
#   storage_path  = "/mnt/plex-data"     # Mount point on Proxmox host
#   nfs_server    = "10.10.0.50"         # Your NFS server IP (TrueNAS/NAS)
#   nfs_path      = "/tank/plex"         # NFS export path
#   nfs_options   = "vers=4,soft,timeo=600,retrans=2,rsize=1048576,wsize=1048576"
#
#   # SMB settings (not used with NFS)
#   smb_server    = null
#   smb_share     = null
#   smb_username  = null
#   smb_password  = null
#   smb_options   = null
#
#   # Optional: Mount media library via NFS
#   media_mounts = [
#     {
#       type        = "nfs"
#       source      = "/mnt/media"        # Mount on Proxmox host
#       target      = "/media"            # Path in container
#       read_only   = true
#       nfs_server  = "10.10.0.50"
#       nfs_options = "vers=4,ro,soft"
#       smb_server  = null
#       smb_share   = null
#     }
#   ]
# }

# EXAMPLE: SMB CONFIGURATION (ALTERNATIVE)
# plex_lxc = {
#   enabled       = true
#   name          = "plex"
#   ip            = "10.10.0.30"
#   cores         = 4
#   memory        = 4096
#   disk          = 32
#   gpu_pci_id    = "0000:00:00.0"
#
#   # SMB storage configuration
#   storage_type  = "smb"
#   storage_path  = "/mnt/plex-data"
#   nfs_server    = null
#   nfs_path      = null
#   nfs_options   = null
#   smb_server    = "10.10.0.50"
#   smb_share     = "plex"
#   smb_username  = "plexuser"
#   smb_password  = "YourSecurePassword"  # ⚠️ Stored in Terraform state
#   smb_options   = "vers=3.0,rw,noperm"
#
#   media_mounts = []
# }
