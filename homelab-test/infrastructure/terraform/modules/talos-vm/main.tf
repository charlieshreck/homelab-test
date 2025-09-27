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
variable "talos_version" { type = string }
variable "gpu_passthrough" { 
  type    = bool
  default = false
}

resource "proxmox_vm_qemu" "talos_node" {
  name        = var.vm_name
  vmid        = var.vm_id
  target_node = var.target_node
  
  # Use Talos ISO
  iso = "${var.iso_storage}:iso/talos-amd64.iso"
  
  cores   = var.cores
  sockets = 1
  memory  = var.memory
  
  agent = 0
  
  # Disk
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
  
  # Network
  network {
    model  = "virtio"
    bridge = var.network_bridge
  }
  
  # Cloud-init for IP (Talos will override)
  ipconfig0 = "ip=${var.ip_address}/24,gw=${var.gateway}"
  nameserver = join(" ", var.dns)
  
  # GPU Passthrough (if enabled)
  dynamic "hostpci0" {
    for_each = var.gpu_passthrough ? [1] : []
    content {
      host    = "00:02.0"  # Intel iGPU - adjust PCI ID for your system
      pcie    = 1
      rombar  = 1
    }
  }
  
  # Boot order
  boot = "order=scsi0"
  
  lifecycle {
    ignore_changes = [
      network,
      iso,
    ]
  }
}
