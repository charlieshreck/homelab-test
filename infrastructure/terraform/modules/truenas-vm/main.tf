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
variable "iso_storage" { type = string }
variable "media_network" {
  type = object({
    bridge = string
    ip     = string
    vlan   = number
  })
  default = null
}

resource "proxmox_virtual_environment_vm" "truenas_node" {
  name        = var.vm_name
  vm_id       = var.vm_id
  node_name   = var.target_node
  
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
    file_id   = "${var.iso_storage}:iso/truenas-scale.iso"
  }
  
  # Main network interface
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }
  
  # Media network interface
  dynamic "network_device" {
    for_each = var.media_network != null ? [1] : []
    content {
      bridge  = var.media_network.bridge
      model   = "virtio"
      vlan_id = var.media_network.vlan
    }
  }
  
  operating_system {
    type = "l26"
  }
  
  agent {
    enabled = false
  }
  
  lifecycle {
    ignore_changes = [
      cdrom,
      initialization
    ]
  }
}
