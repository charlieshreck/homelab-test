terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.89"
    }
  }
}

resource "proxmox_virtual_environment_container" "plex" {
  node_name    = var.proxmox_node
  vm_id        = var.vm_id
  description  = "Plex Media Server with AMD 680M GPU passthrough"
  tags         = ["plex", "media", "gpu"]

  # Privileged container for GPU access
  unprivileged = false

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  initialization {
    hostname = var.hostname

    # Primary NIC - Management/External access
    ip_config {
      ipv4 {
        address = "${var.management_ip}/24"
        gateway = var.gateway
      }
    }

    # Secondary NIC - Media/storage network (no gateway)
    ip_config {
      ipv4 {
        address = "${var.media_network_ip}/24"
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  cpu {
    architecture = "amd64"
    cores        = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = 512
  }

  # Root filesystem
  disk {
    datastore_id = var.storage_pool
    size         = var.disk_size_gb
  }

  # Primary network - Management (vmbr0)
  network_interface {
    name   = "eth0"
    bridge = var.management_bridge
  }

  # Secondary network - Media/NFS (vmbr1)
  network_interface {
    name   = "eth1"
    bridge = var.media_bridge
  }

  features {
    nesting = true
    fuse    = true
  }

  startup {
    order      = "2"
    up_delay   = 30
    down_delay = 30
  }

  # Note: GPU passthrough configured via script after creation
  # because Terraform LXC provider doesn't support dev0 directly

  lifecycle {
    ignore_changes = [
      # Ignore changes made by GPU config script
      description
    ]
  }
}

# Output container ID for GPU configuration script
resource "local_file" "plex_container_id" {
  content  = proxmox_virtual_environment_container.plex.vm_id
  filename = "${path.module}/../../../generated/plex_container_id"
}
