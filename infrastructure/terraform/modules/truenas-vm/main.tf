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
variable "gpu_passthrough" { 
  type    = bool
  default = false
}

resource "proxmox_virtual_environment_vm" "talos_node" {
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
    enabled   = true
    file_id   = "${var.iso_storage}:iso/talos-amd64.iso"
  }
  
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
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
  
  dynamic "hostpci" {
    for_each = var.gpu_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      id      = "0000:00:02.0"
      pcie    = true
      rombar  = true
    }
  }
  
  operating_system {
    type = "l26"
  }
  
  agent {
    enabled = false
  }
}
