# Proxmox Connection
proxmox_host     = "10.30.0.10"
proxmox_user     = "root@pam"
proxmox_password = "H4ckwh1z"
proxmox_node     = "Carrick"

# Networks
prod_network              = "10.30.0.0/24"
prod_gateway              = "10.30.0.1"
proxmox_internal_network  = "172.10.0.0/24"
proxmox_internal_gateway  = "172.10.0.1"
truenas_network           = "172.20.0.0/24"
truenas_gateway           = "172.20.0.1"
dns_servers               = ["1.1.1.1", "8.8.8.8"]
network_bridge            = "vmbr0"

# Cluster - LATEST STABLE VERSIONS
cluster_name       = "homelab-test"
talos_version      = "v1.11.2"

# Storage - Longhorn for persistent storage
proxmox_storage          = "Kerrier"
proxmox_longhorn_storage = "Restormal"
proxmox_truenas_storage  = "Trelawney"
proxmox_iso_storage      = "local"

# VM ID Management
vm_id_start = 200

# Control Plane
control_plane = {
  name   = "talos-cp-01"
  ip     = "10.30.0.50"
  cores  = 2
  memory = 4096
  disk   = 100
}

# Workers - Longhorn storage disks
workers = [
  {
    name          = "talos-worker-01"
    ip            = "10.30.0.51"
    cores         = 4
    memory        = 8192
    disk          = 100
    gpu           = false
    gpu_pci_id    = "0000:00:02.0"
    longhorn_disk = 300
  },
  {
    name          = "talos-worker-02"
    ip            = "10.30.0.52"
    cores         = 4
    memory        = 8192
    disk          = 100
    gpu           = false
    gpu_pci_id    = null
    longhorn_disk = 300
  }
]

# TrueNAS
truenas_vm = {
  name     = "truenas"
  ip       = "10.30.0.20"
  cores    = 4
  memory   = 16384
  disk     = 100
  media_ip = "172.20.0.20"
}

# GitOps Configuration
gitops_repo_url    = "https://github.com/charlieshreck/homelab-test.git"
gitops_repo_branch = "main"
github_token       = "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"

# MetalLB IP Range - adjust for your network
metallb_ip_range = ["10.30.0.60-10.30.0.80"]