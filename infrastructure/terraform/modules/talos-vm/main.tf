terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos_node" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = var.target_node
  machine   = "pc"
  bios      = "seabios"

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

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = disk.value.storage
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = "raw"
    }
  }

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["ide3", "scsi0"]

  cdrom {
 #   enabled   = true
    file_id   = var.iso_file
    interface = "ide3"
  }

  network_device {
    bridge      = var.network_bridge
    model       = "virtio"
    mac_address = var.mac_address != "" ? var.mac_address : null
  }

  dynamic "hostpci" {
    for_each = var.gpu_passthrough && var.gpu_pci_id != null ? [1] : []
    content {
      device = "hostpci0"
      id     = var.gpu_pci_id
      pcie   = false
      rombar = true
    }
  }

  operating_system {
    type = "l26"
  }

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
    ignore_changes = [cdrom]
  }
}


output "vm_id" {
  value = proxmox_virtual_environment_vm.talos_node.vm_id
}

output "name" {
  value = var.vm_name
}

output "ip_address" {
  value = var.ip_address
}