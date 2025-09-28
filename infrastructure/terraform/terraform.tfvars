# Proxmox Connection
proxmox_host         = "10.30.0.10"
proxmox_user     = "root@pam"
proxmox_password = "H4ckwh1z"
proxmox_node         = "Carrick"

# Networks
prod_network              = "10.30.0.0/24"
prod_gateway              = "10.30.0.1"
proxmox_internal_network  = "172.10.0.0/24"
proxmox_internal_gateway  = "172.10.0.1"
truenas_network           = "172.20.0.0/24"
truenas_gateway           = "172.20.0.1"
dns_servers               = ["1.1.1.1", "8.8.8.8"]

# Cluster
cluster_name       = "homelab-test"
talos_version      = "v1.11.2"
kubernetes_version = "v1.31.0"

# Storage
proxmox_storage     = "Kerrier"
proxmox_iso_storage = "local"
network_bridge      = "vmbr0"
