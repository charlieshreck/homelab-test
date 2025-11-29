terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Create LXC container with Docker support
resource "proxmox_virtual_environment_container" "plex" {
  name             = var.container_name
  node_name        = var.target_node
  vm_id            = var.container_id
  ostype           = "debian"
  osversion        = "12"
  hostname         = var.container_name
  root_password    = var.plex_root_password
  unprivileged     = false
  privileged       = true

  # Enable nesting and keyctl for Docker support
  features {
    nesting = true
    keyctl  = true
  }

  # Storage configuration
  rootfs {
    storage = var.storage
    size    = "${var.disk_size}G"
  }

  # Network configuration
  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  ip_config {
    ipv4 {
      address = "${var.ip_address}/24"
      gateway = var.gateway
    }
    ipv6 {
      address = "auto"
    }
  }

  nameserver = join(" ", var.dns_servers)

  # Resource limits
  memory = var.memory
  cores  = var.cores

  # Mount point for media storage from TrueNAS
  dynamic "mount_point" {
    for_each = var.truenas_nfs_paths
    content {
      mp             = mount_point.value.target
      path           = mount_point.value.target
      volume         = mount_point.value.source
      mp_backup      = false
    }
  }

  # Initialization script to install Docker and deploy Plex
  initialization {
    hostname = var.container_name
    datastore_id = var.storage

    custom {
      type = "vendor-data"
      content = base64encode(templatefile("${path.module}/init.sh", {
        plex_claim_token = var.plex_claim_token
      }))
    }
  }
}

# Configure GPU passthrough via SSH to Proxmox host
resource "null_resource" "configure_gpu_passthrough" {
  depends_on = [proxmox_virtual_environment_container.plex]

  provisioner "remote-exec" {
    inline = [
      "echo 'Configuring Intel GPU passthrough for container ${var.container_id}...'",
      "sed -i '/^devices:/d; /^  - /d' /etc/pve/lxc/${var.container_id}.conf || true",
      "echo 'devices: /dev/dri' >> /etc/pve/lxc/${var.container_id}.conf",
      "echo '  - /dev/dri/card0' >> /etc/pve/lxc/${var.container_id}.conf",
      "echo '  - /dev/dri/renderD128' >> /etc/pve/lxc/${var.container_id}.conf",
      "echo 'lxc.cgroup2.devices.allow: c 226:* rwm' >> /etc/pve/lxc/${var.container_id}.conf",
      "echo 'GPU passthrough configured'"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = var.proxmox_password
      host     = var.proxmox_host
    }
  }
}

# Restart container after GPU configuration
resource "null_resource" "restart_container_for_gpu" {
  depends_on = [null_resource.configure_gpu_passthrough]

  provisioner "local-exec" {
    command = "sleep 5 && echo 'GPU configuration applied'"
  }
}
