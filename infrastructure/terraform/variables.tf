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

variable "storage_bridge" {
  description = "The name of the Proxmox network bridge for storage network (Mayastor/TrueNAS)."
  type        = string
}

variable "storage_gateway" {
  description = "The gateway IP address for the storage network."
  type        = string
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "proxmox_storage" {
  description = "The name of the main Proxmox storage pool for OS disks."
  type        = string
}

variable "proxmox_mayastor_storage" {
  description = "The name of the high-performance storage pool dedicated to Mayastor (helford - 1TB)."
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
  description = "A map of worker node configurations with dual NICs for management and storage networks."
  type = map(object({
    name          = string
    ip            = string
    storage_ip    = string
    cores         = number
    memory        = number
    disk          = number
    gpu           = bool
    gpu_pci_id    = optional(string)
    mayastor_disk = number
  }))
}

variable "storage_nodes" {
  description = "A map of storage node configurations (deprecated - using workers for Mayastor)."
  type = map(object({
    name          = string
    ip            = string
    storage_ip    = string
    cores         = number
    memory        = number
    disk          = number
    gpu           = bool
    gpu_pci_id    = optional(string)
    mayastor_disk = number
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

variable "cilium_lb_ip_pool" {
  description = "The IP address range for Cilium LoadBalancer to assign to LoadBalancer services."
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

# ==============================================================================
# Container Registry Configuration
# ==============================================================================

variable "dockerhub_username" {
  description = "Docker Hub username for authenticated pulls (avoids rate limiting)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dockerhub_password" {
  description = "Docker Hub password or access token for authenticated pulls"
  type        = string
  default     = ""
  sensitive   = true
}

# ==============================================================================
# Plex LXC Configuration
# ==============================================================================

variable "ssh_public_keys" {
  description = "SSH public keys for container root access (optional)"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Restic Backup LXC Configuration
# ==============================================================================

variable "restic_lxc_vm_id" {
  description = "Proxmox VM ID for the Restic backup LXC container (unique, 100-999)"
  type        = number
}

variable "restic_lxc_cores" {
  description = "Number of CPU cores for Restic LXC"
  type        = number
  default     = 4
}

variable "restic_lxc_memory" {
  description = "RAM in MB for Restic LXC"
  type        = number
  default     = 2048
}

variable "restic_lxc_disk" {
  description = "Root disk size in GB for Restic LXC"
  type        = number
  default     = 20
}

variable "restic_lxc_ip" {
  description = "Static IP address for Restic LXC (leave empty for DHCP)"
  type        = string
  default     = ""
}

# ==============================================================================
# Backup Configuration (Deprecated - Secrets now fetched from Infisical)
# ==============================================================================
#
# NOTE: The following variables are DEPRECATED. Secrets are now fetched from
# Infisical automatically via the Infisical provider in infisical-secrets.tf.
# These variables are kept for backward compatibility but are no longer needed.
#
# Required Infisical secrets in /backups path:
#   - PLEX_ROOT_PASSWORD: Root password for Plex LXC container
#   - PLEX_CLAIM_TOKEN: (Optional) Plex claim token for auto-claiming
#   - RESTIC_PASSWORD: Encryption password for Restic backups
#   - MINIO_ACCESS_KEY: MinIO access key for backups
#   - MINIO_SECRET_KEY: MinIO secret key for backups

variable "plex_root_password" {
  description = "DEPRECATED: Fetched from Infisical secret PLEX_ROOT_PASSWORD in /backups"
  type        = string
  sensitive   = true
  default     = ""
}

variable "plex_claim_token" {
  description = "DEPRECATED: Fetched from Infisical secret PLEX_CLAIM_TOKEN in /backups (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "restic_encryption_password" {
  description = "DEPRECATED: Fetched from Infisical secret RESTIC_PASSWORD in /backups"
  type        = string
  sensitive   = true
  default     = ""
}

variable "minio_access_key" {
  description = "DEPRECATED: Fetched from Infisical secret MINIO_ACCESS_KEY in /backups"
  type        = string
  sensitive   = true
  default     = ""
}

variable "minio_secret_key" {
  description = "DEPRECATED: Fetched from Infisical secret MINIO_SECRET_KEY in /backups"
  type        = string
  sensitive   = true
  default     = ""
}