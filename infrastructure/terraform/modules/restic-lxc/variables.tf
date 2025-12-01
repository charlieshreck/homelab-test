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

variable "template_storage" {
  description = "Proxmox storage where LXC templates are stored (e.g., local)"
  type        = string
  default     = "local"
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

variable "root_password" {
  description = "Root password for the LXC container"
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys for root user"
  type        = list(string)
  default     = []
}

variable "restic_repository" {
  description = "Restic repository URL (e.g., s3:http://host:port/bucket)"
  type        = string
  sensitive   = true
}

variable "restic_password" {
  description = "Restic repository encryption password"
  type        = string
  sensitive   = true
}

variable "minio_access_key" {
  description = "MinIO access key for S3 backups"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key for S3 backups"
  type        = string
  sensitive   = true
}
