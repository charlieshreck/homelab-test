variable "vm_name" { type = string }
variable "vm_id" { type = number }
variable "target_node" { type = string }
variable "cores" { type = number }
variable "memory" { type = number }
variable "disk" { type = number }
variable "ip_address" { type = string }
variable "gateway" { type = string }
variable "dns" { type = list(string) }
variable "network_bridge" { type = string }
variable "storage" { type = string }
variable "iso_storage" { type = string }
variable "mac_address" {
  type        = string
  default     = ""
  description = "Fixed MAC address for DHCP reservation"
}

variable "enable_storage_network" {
  type        = bool
  default     = false
  description = "Enable second NIC for storage network (NFS/SMB)"
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

variable "media_network" {
  type = object({
    bridge = string
    ip     = string
    vlan   = number
  })
  default = null
  description = "Legacy media network configuration (deprecated - use storage_bridge)"
}
