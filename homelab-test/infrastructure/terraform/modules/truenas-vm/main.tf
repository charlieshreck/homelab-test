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

resource "proxmox_vm_qemu" "truenas" {
  name        = var.vm_name
  vmid        = var.vm_id
  target_node = var.target_node
  
  # You'll need to upload TrueNAS ISO manually
  iso = "local:iso/truenas-scale.iso"
  
  cores   = var.cores
  sockets = 1
  memory  = var.memory
  
  agent = 1
  
  # System disk
  disks {
    scsi {
      scsi0 {
        disk {
          size    = var.disk
          storage = var.storage
        }
      }
    }
  }
  
  # Network on separate bridge/VLAN
  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = 20  # VLAN 20 for TrueNAS network
  }
  
  ipconfig0  = "ip=${var.ip_address}/24,gw=${var.gateway}"
  nameserver = join(" ", var.dns)
  
  # USB passthrough will be configured manually in Proxmox
  
  boot = "order=scsi0"
  
  lifecycle {
    ignore_changes = [
      network,
      iso,
    ]
  }
}
