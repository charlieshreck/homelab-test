# Proxmox Connection
proxmox_host     = "10.30.0.10"
proxmox_user     = "root@pam"
proxmox_password  = "H4ckwh1z"
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

# Cluster
cluster_name       = "homelab-test"
talos_version      = "v1.8.2"
kubernetes_version = "v1.31.0"

# Storage
proxmox_storage          = "Kerrier"
proxmox_longhorn_storage = "Restormal"
proxmox_truenas_storage  = "Trelawney"
proxmox_iso_storage      = "local"

# VM ID Management
vm_id_start = 200

# Control Plane
control_plane = {
  name   = "talos-cp-01"
  ip     = "10.30.0.11"
  cores  = 2
  memory = 4096
  disk   = 100
}

# Workers
workers = [
  {
    name          = "talos-worker-01"
    ip            = "10.30.0.12"
    cores         = 4
    memory        = 8192
    disk          = 100
    gpu           = true
    longhorn_disk = 300
  },
  {
    name          = "talos-worker-02"
    ip            = "10.30.0.13"
    cores         = 4
    memory        = 8192
    disk          = 100
    gpu           = false
    longhorn_disk = 300
  }
]

# TrueNAS
truenas_vm = {
  name     = "truenas"
  ip       = "10.30.0.20"
  cores    = 4
  memory   = 16384
  disk     = 500
  media_ip = "172.20.0.20"
}
