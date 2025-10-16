# ==============================================================================
# Provider Configuration
# ==============================================================================

variable "proxmox_host" {
  description = "The FQDN or IP address of the Proxmox host."
  type        = string
}

variable "proxmox_user" {
  description = "The Proxmox user, including the realm (e.g., 'root@pam')."
  type        = string
}

variable "proxmox_password" {
  description = "The password for the Proxmox user."
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "The specific Proxmox node where VMs will be created (e.g., 'pve')."
  type        = string
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "prod_gateway" {
  description = "The gateway IP address for the main production network."
  type        = string
}

variable "dns_servers" {
  description = "A list of DNS servers for the VMs."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_bridge" {
  description = "The name of the Proxmox network bridge for VMs to connect to (e.g., 'vmbr0')."
  type        = string
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "proxmox_storage" {
  description = "The name of the main Proxmox storage pool for OS disks."
  type        = string
}

variable "proxmox_longhorn_storage" {
  description = "The name of the high-performance storage pool dedicated to Longhorn."
  type        = string
}

#variable "proxmox_truenas_storage" {
#  description = "The name of the storage pool for the TrueNAS VM's data."
#  type        = string
#}

variable "proxmox_iso_storage" {
  description = "The name of the Proxmox storage pool where ISO images are stored."
  type        = string
}

# ==============================================================================
# Cluster Configuration
# ==============================================================================

variable "cluster_name" {
  description = "A name for the Kubernetes cluster."
  type        = string
  default     = "homelab-test"
}

variable "talos_version" {
  description = "The version of Talos OS to install."
  type        = string
  default     = "v1.11.3"
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to deploy."
  type        = string
  default     = "v1.34.1"
}

variable "vm_id_start" {
  description = "The starting ID for Proxmox VMs. Terraform will increment from this number."
  type        = number
  default     = 200
}

# ==============================================================================
# VM Definitions
# ==============================================================================

variable "control_plane" {
  description = "The configuration for the control plane node."
  type = object({
    name   = string
    ip     = string
    cores  = number
    memory = number
    disk   = number
  })
}

variable "workers" {
  description = "A map of worker node configurations, keyed by a unique name like 'worker-01'."
  type = map(object({
    name          = string
    ip            = string
    cores         = number
    memory        = number
    disk          = number
    gpu           = bool
    gpu_pci_id    = optional(string)
    longhorn_disk = number
  }))
}

variable "storage_nodes" {
  description = "A map of storage node configurations for Longhorn."
  type = map(object({
    name          = string
    ip            = string
    cores         = number
    memory        = number
    disk          = number
    gpu           = bool
    gpu_pci_id    = optional(string)
    longhorn_disk = number
  }))
  default = {}
}

variable "truenas_vm" {
  description = "The configuration for the TrueNAS VM."
  type = object({
    name     = string
    ip       = string
    cores    = number
    memory   = number
    disk     = number
    media_ip = string
  })
  default = null
}

# ==============================================================================
# GitOps & Application Configuration
# ==============================================================================

variable "gitops_repo_url" {
  description = "The Git repository URL for ArgoCD to synchronize with."
  type        = string
}

variable "gitops_repo_branch" {
  description = "The Git branch for ArgoCD to watch."
  type        = string
  default     = "main"
}

variable "metallb_ip_range" {
  description = "The IP address range for MetalLB to assign to LoadBalancer services."
  type        = list(string)
}

variable "longhorn_managed_by_argocd" {
  description = "Set to true if Longhorn is managed by ArgoCD instead of Terraform."
  type        = bool
  default     = false
}

# ==============================================================================
# Cloudflare Configuration
# ==============================================================================

variable "cloudflare_email" {
  description = "The email address associated with your Cloudflare account."
  type        = string
}

variable "cloudflare_domain" {
  description = "The root domain you manage in Cloudflare (e.g., 'example.com')."
  type        = string
}

# ==============================================================================
# Secrets Management - Infisical
# ==============================================================================

variable "infisical_client_id" {
  description = "Infisical Universal Auth Client ID"
  type        = string
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Infisical Universal Auth Client Secret"
  type        = string
  sensitive   = true
}