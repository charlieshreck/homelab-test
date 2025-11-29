variable "vm_name" {
  description = "Name of the Restic LXC container"
  type        = string
  default     = "restic-backup"
}

variable "vm_id" {
  description = "Proxmox VM ID for the Restic LXC (unique, 100-999)"
  type        = number
}

variable "target_node" {
  description = "Proxmox node where the LXC will be created"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "swap" {
  description = "Swap space in MB"
  type        = number
  default     = 512
}

variable "root_disk_size" {
  description = "Root filesystem size in GB"
  type        = number
  default     = 20
}

variable "storage" {
  description = "Proxmox storage pool for the LXC root filesystem"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge for the LXC (e.g., vmbr0)"
  type        = string
}

variable "ip_address" {
  description = "Static IP address for the LXC (leave empty for DHCP)"
  type        = string
  default     = ""
}

variable "gateway" {
  description = "Default gateway IP address"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}
