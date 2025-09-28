# Provider Configuration
variable "proxmox_host" {
  description = "Proxmox host IP or hostname"
  type        = string
  default     = "10.30.0.10"
}

variable "proxmox_user" {
  description = "Proxmox user"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "Carrick"
}

# Network Configuration
variable "prod_network" {
  description = "Production network CIDR"
  type        = string
  default     = "10.30.0.0/24"
}

variable "prod_gateway" {
  description = "Production network gateway"
  type        = string
  default     = "10.30.0.1"
}

variable "proxmox_internal_network" {
  description = "Internal network for Proxmox VMs"
  type        = string
  default     = "172.10.0.0/24"
}

variable "proxmox_internal_gateway" {
  description = "Internal network gateway"
  type        = string
  default     = "172.10.0.1"
}

variable "truenas_network" {
  description = "TrueNAS media network"
  type        = string
  default     = "172.20.0.0/24"
}

variable "truenas_gateway" {
  description = "TrueNAS network gateway"
  type        = string
  default     = "172.20.0.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

# Storage Configuration
variable "proxmox_storage" {
  description = "Main VM storage pool"
  type        = string
  default     = "Kerrier"
}

variable "proxmox_longhorn_storage" {
  description = "Longhorn storage pool (NVMe)"
  type        = string
  default     = "Restormal"
}

variable "proxmox_truenas_storage" {
  description = "TrueNAS storage pool"
  type        = string
  default     = "Trelawney"
}

variable "proxmox_iso_storage" {
  description = "ISO storage"
  type        = string
  default     = "local"
}

# Cluster Configuration
variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "homelab-test"
}

variable "talos_version" {
  description = "Talos version"
  type        = string
  default     = "v1.8.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.31.0"
}

# VM ID Management
variable "vm_id_start" {
  description = "Starting VM ID"
  type        = number
  default     = 200
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
    disk   = 100
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
      disk         = 100
      gpu          = true
      longhorn_disk = 300
    },
    {
      name         = "talos-worker-02"
      ip           = "10.30.0.13"
      cores        = 4
      memory       = 8192
      disk         = 100
      gpu          = false
      longhorn_disk = 300
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
    disk   = 500
    media_ip = "172.20.0.20"
  }
}
