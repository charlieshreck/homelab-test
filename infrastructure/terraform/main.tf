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
variable "talos_version" { type = string }
variable "gpu_passthrough" { 
  type    = bool
  default = false
}
variable "additional_disks" {
  type = list(object({
    size      = number
    storage   = string
    interface = string
  }))
  default = []
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
  
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }
  
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
  
  machine = "pc"
  
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
