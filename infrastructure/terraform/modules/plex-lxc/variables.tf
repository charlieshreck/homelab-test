variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "vm_id" {
  description = "Container ID"
  type        = number
  default     = 220
}

variable "hostname" {
  description = "Container hostname"
  type        = string
  default     = "plex"
}

variable "template_file_id" {
  description = "Proxmox template file ID"
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "management_ip" {
  description = "IP address on management network"
  type        = string
}

variable "media_network_ip" {
  description = "IP address on media/storage network"
  type        = string
}

variable "gateway" {
  description = "Default gateway (management network only)"
  type        = string
}

variable "management_bridge" {
  description = "Proxmox bridge for management network"
  type        = string
  default     = "vmbr0"
}

variable "media_bridge" {
  description = "Proxmox bridge for media network"
  type        = string
  default     = "vmbr1"
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 50
}

variable "storage_pool" {
  description = "Proxmox storage pool for container disk"
  type        = string
  default     = "local-lvm"
}

variable "ssh_public_keys" {
  description = "SSH public keys for access"
  type        = list(string)
}
