terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://${var.proxmox_host}:8006/api2/json"
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
  pm_tls_insecure     = true
}

# Control Plane Node
module "control_plane" {
  source = "./modules/talos-vm"

  vm_name     = var.control_plane.name
  vm_id       = 100
  target_node = var.proxmox_node
  
  cores  = var.control_plane.cores
  memory = var.control_plane.memory
  disk   = var.control_plane.disk
  
  ip_address = var.control_plane.ip
  gateway    = var.prod_gateway
  dns        = var.dns_servers
  
  network_bridge = var.network_bridge
  storage        = var.proxmox_vm_storage
  iso_storage    = var.proxmox_iso_storage
  
  talos_version = var.talos_version
}

# Worker Nodes
module "workers" {
  source   = "./modules/talos-vm"
  count    = length(var.workers)

  vm_name     = var.workers[count.index].name
  vm_id       = 110 + count.index
  target_node = var.proxmox_node
  
  cores  = var.workers[count.index].cores
  memory = var.workers[count.index].memory
  disk   = var.workers[count.index].disk
  
  ip_address = var.workers[count.index].ip
  gateway    = var.prod_gateway
  dns        = var.dns_servers
  
  network_bridge = var.network_bridge
  storage        = var.proxmox_longhorn_storage  # Longhorn uses Restormal
  iso_storage    = var.proxmox_iso_storage
  
  talos_version = var.talos_version
  
  # GPU passthrough for first worker
  gpu_passthrough = var.workers[count.index].gpu
}

# TrueNAS VM
module "truenas" {
  source = "./modules/truenas-vm"

  vm_name     = var.truenas.name
  vm_id       = 200
  target_node = var.proxmox_node
  
  cores  = var.truenas.cores
  memory = var.truenas.memory
  disk   = var.truenas.disk
  
  ip_address = var.truenas.ip
  gateway    = var.truenas_gateway
  dns        = var.dns_servers
  
  network_bridge = var.network_bridge
  storage        = var.proxmox_truenas_storage  # TrueNAS uses Trelawney
}
