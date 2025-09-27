terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

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

resource "proxmox_virtual_environment_vm" "truenas" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = var.target_node
  
  cpu {
    cores = var.cores
    type  = "host"
  }
  
  memory {
    dedicated = var.memory
  }
  
  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = var.disk
    file_format  = "raw"
  }
  
  cdrom {
    enabled = true
    file_id = "local:iso/truenas-scale.iso"
  }
  
  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
    vlan_id = 20
  }
  
  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address}/24"
        gateway = var.gateway
      }
    }
    dns {
      servers = var.dns
    }
  }
  
  operating_system {
    type = "l26"
  }
  
  agent {
    enabled = true
  }
}
