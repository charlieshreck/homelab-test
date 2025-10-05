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
  default     = "v1.11.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.34.1"
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
    ip     = "10.30.0.50"
    cores  = 2
    memory = 4096
    disk   = 100
  }
}

# Worker Nodes Configuration
variable "workers" {
  description = "Worker nodes configuration"
  type = list(object({
    name          = string
    ip            = string
    cores         = number
    memory        = number
    disk          = number
    gpu           = bool
    gpu_pci_id    = optional(string)
    longhorn_disk = number
  }))
  default = [
    {
      name          = "talos-worker-01"
      ip            = "10.30.0.51"
      cores         = 4
      memory        = 8192
      disk          = 100
      gpu           = true
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
}

# TrueNAS Configuration
variable "truenas_vm" {
  description = "TrueNAS VM configuration"
  type = object({
    name     = string
    ip       = string
    cores    = number
    memory   = number
    disk     = number
    media_ip = string
  })
  default = {
    name     = "truenas"
    ip       = "10.30.0.20"
    cores    = 4
    memory   = 16384
    disk     = 500
    media_ip = "172.20.0.20"
  }
}

# GitOps Configuration
variable "gitops_repo_url" {
  description = "Git repository URL for ArgoCD to watch"
  type        = string
}

variable "gitops_repo_branch" {
  description = "Git branch for ArgoCD to watch"
  type        = string
  default     = "main"
}

# Optional: For private repositories
variable "github_token" {
  description = "GitHub Personal Access Token for private repos"
  type        = string
  sensitive   = true
  default     = ""
}

# MetalLB Configuration
variable "metallb_ip_range" {
  description = "IP address range for MetalLB LoadBalancer services"
  type        = list(string)
  default     = ["10.30.0.60-10.30.0.80"]
}
# ==============================================================================
# Cloudflare Configuration (for cert-manager and Tunnels)
# ==============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token - retrieve from Vault or set via environment"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_email" {
  description = "Cloudflare account email"
  type        = string
  default     = ""
}

variable "cloudflare_domain" {
  description = "Primary domain managed in Cloudflare"
  type        = string
  default     = "shreck.io"
}

# ==============================================================================
# Platform Components Control
# ==============================================================================

variable "longhorn_managed_by_argocd" {
  description = "Set to true to skip Terraform deployment of Longhorn"
  type        = bool
  default     = false
}
