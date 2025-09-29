terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
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
  
  # Primary disk
  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = var.disk
    file_format  = "raw"
  }
  
  # Additional disks for Longhorn storage
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = disk.value.storage
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = "raw"
    }
  }
  
  cdrom {
    file_id   = "${var.iso_storage}:iso/talos-amd64.iso"
  }
  
  # Main network interface with fixed MAC for DHCP reservation
  network_device {
    bridge      = var.network_bridge
    model       = "virtio"
    mac_address = var.mac_address != "" ? var.mac_address : null
  }
  
  # Internal network interface for cluster communication
  network_device {
    bridge      = "vmbr1"
    model       = "virtio"
    mac_address = var.internal_mac_address != "" ? var.internal_mac_address : null
  }
  
  # GPU passthrough (optional)
  dynamic "hostpci" {
    for_each = var.gpu_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      id      = "00:02.0"
      pcie    = false
      rombar  = true
    }
  }
  
  operating_system {
    type = "l26"
  }
  
  bios = "seabios"
  
  serial_device {
    device = "socket"
  }
  
  agent {
    enabled = false
  }
  
  startup {
    order      = 1
    up_delay   = 30
    down_delay = 30
  }
  
  lifecycle {
    ignore_changes = [
      cdrom
    ]
  }
}
