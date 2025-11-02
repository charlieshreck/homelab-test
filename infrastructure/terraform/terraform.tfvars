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
    cores         = 2
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
    cores         = 2
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
    cores         = 2
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
