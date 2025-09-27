variable "proxmox_host" {
  description = "Proxmox host IP"
  type        = string
  default     = "10.30.0.10"
}

variable "proxmox_user" {
  description = "Proxmox username"
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
  description = "Proxmox internal network CIDR"
  type        = string
  default     = "172.10.0.0/24"
}

variable "proxmox_internal_gateway" {
  description = "Proxmox internal gateway"
  type        = string
  default     = "172.10.0.1"
}

variable "truenas_network" {
  description = "TrueNAS network CIDR"
  type        = string
  default     = "172.20.0.0/24"
}

variable "truenas_gateway" {
  description = "TrueNAS gateway"
  type        = string
  default     = "172.20.0.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
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
  default     = "v1.8.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.31.0"
}

# VM Specifications
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

variable "workers" {
  description = "Worker nodes specs"
  type = list(object({
    name   = string
    ip     = string
    cores  = number
    memory = number
    disk   = number
    gpu    = bool
  }))
  default = [
    {
      name   = "talos-worker-01"
      ip     = "10.30.0.21"
      cores  = 4
      memory = 4096
      disk   = 400  # 400GB on Restormal (950GB pool) - GPU node
      gpu    = true  # This worker gets GPU passthrough
    },
    {
      name   = "talos-worker-02"
      ip     = "10.30.0.22"
      cores  = 2
      memory = 4096
      disk   = 400  # 400GB on Restormal (950GB pool)
      gpu    = false
    }
  ]
}

variable "truenas" {
  description = "TrueNAS VM specs"
  type = object({
    name   = string
    ip     = string
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    name   = "truenas"
    ip     = "172.20.0.10"
    cores  = 2
    memory = 4096
    disk   = 32
  }
}

# Storage
variable "proxmox_vm_storage" {
  description = "Proxmox VM storage pool"
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
  description = "Proxmox ISO storage"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Network bridge name"
  type        = string
  default     = "vmbr0"
}
