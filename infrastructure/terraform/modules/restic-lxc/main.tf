terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Create Debian 13 LXC container for Restic backup
resource "proxmox_virtual_environment_container" "restic_lxc" {
  node_name = var.target_node
  vm_id     = var.vm_id
  hostname  = var.vm_name

  # Operating system - use local template
  # Proxmox will use the default Debian 13 template from the local storage
  ostype   = "debian"
  osversion = "13"

  # Root filesystem
  rootfs {
    storage = var.storage
    size    = var.root_disk_size
  }

  # CPU and Memory
  cores  = var.cores
  memory = var.memory
  swap   = var.swap

  # Network configuration
  dynamic "network_interface" {
    for_each = [1]
    content {
      name   = "eth0"
      bridge = var.network_bridge
      ip     = var.ip_address != "" ? "${var.ip_address}/24" : "dhcp"
    }
  }

  # DNS
  dns = join(" ", var.dns_servers)

  # Enable privileged mode for Restic to access other VMs/LXCs
  privileged = true

  # Start on boot
  start = true

  # Features
  features {
    nesting = true
  }
}
