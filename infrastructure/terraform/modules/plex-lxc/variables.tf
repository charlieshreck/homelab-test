variable "container_name" {
  description = "Name of the LXC container"
  type        = string
}

variable "container_id" {
  description = "Numeric ID for the LXC container"
  type        = number
}

variable "target_node" {
  description = "Proxmox node to deploy the container on"
  type        = string
}

variable "ip_address" {
  description = "IP address for the container"
  type        = string
}

variable "gateway" {
  description = "Gateway IP address"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_bridge" {
  description = "Network bridge name"
  type        = string
}

variable "storage" {
  description = "Storage pool for the container"
  type        = string
}

variable "memory" {
  description = "Memory allocation in MB"
  type        = number
  default     = 8192
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "proxmox_host" {
  description = "Proxmox host IP or FQDN for GPU passthrough configuration"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox user for SSH connection"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password for SSH connection"
  type        = string
  sensitive   = true
}

variable "plex_claim_token" {
  description = "Plex claim token for auto-claiming the server"
  type        = string
  default     = ""
  sensitive   = true
}

variable "plex_root_password" {
  description = "Root password for the Plex LXC container"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for root access"
  type        = list(string)
  default     = []
}

variable "truenas_ip" {
  description = "IP address of TrueNAS for NFS mounts"
  type        = string
  default     = "10.20.0.100"
}

variable "truenas_nfs_paths" {
  description = "TrueNAS NFS mount paths for media storage"
  type = map(object({
    source = string
    target = string
  }))
  default = {
    media = {
      source = "10.20.0.100:/mnt/Tongariro/Plexopathy/media"
      target = "/mnt/media"
    }
  }
}
