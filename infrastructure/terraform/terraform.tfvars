# terraform.tfvars - Production setup with optimized disk allocation

# Proxmox Connection
proxmox_host     = "10.30.0.10"
proxmox_user     = "root@pam"
proxmox_password = "H4ckwh1z"
proxmox_node     = "Carrick"

# Networks
prod_gateway     = "10.30.0.1"
network_bridge   = "vmbr0"

# Cluster
cluster_name       = "homelab-test"
talos_version      = "v1.11.3"
kubernetes_version = "v1.34.1"

# Storage
proxmox_storage          = "Kerrier"
proxmox_longhorn_storage = "Restormal"
proxmox_iso_storage      = "local"

# VM ID Management
vm_id_start = 200

# Control Plane
control_plane = {
  name   = "talos-cp-01"
  ip     = "10.30.0.50"
  cores  = 2
  memory = 4096
  disk   = 50
}

# Workers (minimal OS disk)
workers = {
  "worker-01" = {
    name       = "talos-worker-01"
    ip         = "10.30.0.51"
    cores      = 4
    memory     = 10240
    disk       = 30
    gpu        = false
    gpu_pci_id = "0000:00:02.0"
    longhorn_disk = 600
  }
}

# Storage Nodes (Longhorn-only)
storage_nodes = {}


# GitOps Configuration
gitops_repo_url    = "https://github.com/charlieshreck/homelab-test.git"
gitops_repo_branch = "main"

# MetalLB IP Range
metallb_ip_range = ["10.30.0.65-10.30.0.100"]

# Cloudflare Configuration
cloudflare_email     = "charlieshreck@gmail.com"
cloudflare_domain    = "shreck.io"

# Infisical Configuration
infisical_client_id     = "26428618-6807-4a12-a461-33242ec1af50"
infisical_client_secret = "8176c36e0e932f660327236ad288cfb1edbbced739d9c2d074d8cedabf492ee3"
