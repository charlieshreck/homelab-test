# Provider Configuration
variable "proxmox_host" {
  description = "Proxmox host IP or hostname"
  type        = string
  default     = "10.30.0.100"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  default     = "terraform@pam!terraform"
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox root password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "proxmox"
}

# Storage Configuration - Using your actual storage pools
variable "proxmox_vm_storage" {
  description = "Proxmox VM storage pool"
  type        = string
  default     = "Kerrier"  # 500GB pool for VMs
}

variable "proxmox_longhorn_storage" {
  description = "Longhorn storage pool (NVMe)"
  type        = string
  default     = "Restormal"  # 950GB NVMe for Longhorn
}

variable "proxmox_truenas_storage" {
  description = "TrueNAS storage pool"
  type        = string
  default     = "Trelawney"
}

variable "proxmox_iso_storage" {
  description = "Proxmox ISO storage"
  type        = string
  default     = "local"
}

# Network Configuration
variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "10.30.0.1"
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

# VM ID Management - Dynamic allocation
variable "vm_id_start" {
  description = "Starting VM ID for dynamic allocation"
  type        = number
  default     = 200  # Start from 200 to avoid conflicts
}

# Control Plane Configuration
variable "control_plane" {
  description = "Control plane node specs"
  type = object({
    name   = string
    ip     = string
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    name   = "talos-cp-01"
    ip     = "10.30.0.11"
    cores  = 2
    memory = 4096
    disk   = 100  # 100GB on Kerrier (500GB pool)
  }
}

# Worker Nodes Configuration
variable "workers" {
  description = "Worker nodes configuration"
  type = list(object({
    name         = string
    ip           = string
    cores        = number
    memory       = number
    disk         = number
    gpu          = bool
    longhorn_disk = number
  }))
  default = [
    {
      name         = "talos-worker-01"
      ip           = "10.30.0.12"
      cores        = 4
      memory       = 8192
      disk         = 100  # 100GB system disk on Kerrier
      gpu          = true
      longhorn_disk = 300  # 300GB on Restormal for Longhorn
    },
    {
      name         = "talos-worker-02"
      ip           = "10.30.0.13"
      cores        = 4
      memory       = 8192
      disk         = 100  # 100GB system disk on Kerrier
      gpu          = false
      longhorn_disk = 300  # 300GB on Restormal for Longhorn
    }
  ]
}

# TrueNAS Configuration
variable "truenas_vm" {
  description = "TrueNAS VM configuration"
  type = object({
    name   = string
    ip     = string
    cores  = number
    memory = number
    disk   = number
    media_ip = string
  })
  default = {
    name   = "truenas"
    ip     = "10.30.0.20"
    cores  = 4
    memory = 16384
    disk   = 500  # 500GB on Trelawney
    media_ip = "172.20.0.20"
  }
}

# Talos Configuration
variable "talos_version" {
  description = "Talos version"
  type        = string
  default     = "v1.8.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.31.0"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "homelab"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  type        = string
  default     = "https://10.30.0.11:6443"
}
