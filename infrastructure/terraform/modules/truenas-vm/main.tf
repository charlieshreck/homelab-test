terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
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
  
  # Main network interface with fixed MAC for DHCP reservation
  network_device {
    bridge      = var.network_bridge
    model       = "virtio"
    mac_address = var.mac_address != "" ? var.mac_address : null
  }
  operating_system {
    type = "l26"
  }
  
  agent {
    enabled = false
  }
  
  lifecycle {
    ignore_changes = [
      cdrom
    ]
  }
}
