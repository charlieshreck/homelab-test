terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Create Debian 13 LXC container for Restic backup
resource "proxmox_virtual_environment_lxc" "restic_lxc" {
  node_name = var.target_node
  vm_id     = var.vm_id
  hostname  = var.vm_name

  # Operating system
  ostype = "debian"

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
  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = "dhcp"
  }

  # Optional: Static IP configuration
  dynamic "network_interface" {
    for_each = var.ip_address != "" ? [1] : []
    content {
      name       = "eth0"
      bridge     = var.network_bridge
      ip         = "${var.ip_address}/24"
      ip6        = "auto"
      gateway    = var.gateway
      gateway6   = "fe80::1"
    }
  }

  # DNS
  nameserver = join(" ", var.dns_servers)

  # Initialize with Debian 13 (trixie)
  # Note: Container will be created from default Debian 13 template
  # You must have debian-13 template in Proxmox
  osversion = "13"

  # Enable privileged mode for Restic to access other VMs
  unprivileged = false

  # Start on boot
  start = true

  # Resource limits
  limits {
    cpu    = var.cores
    memory = var.memory
  }

  # Features
  features {
    nesting = true
  }
}
