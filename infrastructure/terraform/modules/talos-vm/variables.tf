variable "vm_name" { 
  type = string 
}

variable "vm_id" { 
  type = number 
}

variable "target_node" { 
  type = string 
}

variable "cores" { 
  type = number 
}

variable "memory" { 
  type = number 
}

variable "disk" { 
  type = number 
}

variable "ip_address" { 
  type = string 
}

variable "gateway" { 
  type = string 
}

variable "dns" { 
  type = list(string) 
}

variable "network_bridge" { 
  type = string 
}

variable "storage" { 
  type = string 
}

variable "iso_storage" { 
  type = string 
}

variable "talos_version" { 
  type = string 
}

variable "iso_file" {
  type = string
}

variable "gpu_passthrough" {
  type    = bool
  default = false
}

variable "gpu_pci_id" {
  type        = string
  default     = null
  description = "PCI ID for GPU passthrough (e.g., '0000:00:02.0')"
}

variable "additional_disks" {
  type = list(object({
    size      = number
    storage   = string
    interface = string
  }))
  default = []
}

variable "mac_address" {
  type        = string
  default     = ""
  description = "Fixed MAC address for DHCP reservation"
}

variable "enable_storage_network" {
  type        = bool
  default     = false
  description = "Enable second NIC for storage network (Mayastor)"
}

variable "storage_bridge" {
  type        = string
  default     = ""
  description = "Network bridge for storage network"
}

variable "storage_mac_address" {
  type        = string
  default     = ""
  description = "Fixed MAC address for storage network interface"
}
