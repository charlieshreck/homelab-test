terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Download Debian 13 LXC template if not already present
resource "proxmox_virtual_environment_download_file" "debian_lxc_template" {
  content_type = "vztmpl"
  datastore_id = var.storage
  node_name    = var.target_node
  url          = "http://download.proxmox.com/images/system/debian-13-standard_13.2-1_amd64.tar.zst"
  file_name    = "debian-13-standard_13.2-1_amd64.tar.zst"

  overwrite           = false
  overwrite_unmanaged = true
}

# Create Debian 13 LXC container for Restic backup
resource "proxmox_virtual_environment_container" "restic_lxc" {
  depends_on = [proxmox_virtual_environment_download_file.debian_lxc_template]

  node_name = var.target_node
  vm_id     = var.vm_id

  # Operating system with template reference
  operating_system {
    type          = "debian"
    template_file_id = proxmox_virtual_environment_download_file.debian_lxc_template.id
  }

  # Root filesystem
  disk {
    datastore_id = var.storage
    size         = var.root_disk_size
  }

  # CPU configuration
  cpu {
    cores = var.cores
  }

  # Memory configuration
  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  # Network configuration with initialization
  initialization {
    hostname = var.vm_name

    ip_config {
      ipv4 {
        address = var.ip_address != "" ? "${var.ip_address}/24" : "dhcp"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    # Create root user account with password
    user_account {
      keys = var.ssh_public_keys
      password = var.root_password
    }
  }

  # Network interface
  network_interface {
    name = "eth0"
    bridge = var.network_bridge
  }

  # Run as unprivileged container
  unprivileged = true

  # Start on boot
  start_on_boot = true

  # Features
  features {
    nesting = true
  }
}

# Wait for SSH to be available
resource "null_resource" "wait_for_ssh" {
  depends_on = [proxmox_virtual_environment_container.restic_lxc]

  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      user        = "root"
      password    = var.root_password
      host        = var.ip_address != "" ? var.ip_address : "127.0.0.1"
      timeout     = "5m"
      agent       = false
    }
  }
}

# Install Restic and configure backups
resource "null_resource" "configure_restic" {
  depends_on = [null_resource.wait_for_ssh]

  # Install restic
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y restic",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      password    = var.root_password
      host        = var.ip_address != "" ? var.ip_address : "127.0.0.1"
      timeout     = "10m"
      agent       = false
    }
  }

  # Create restic configuration file
  provisioner "file" {
    content = templatefile("${path.module}/templates/restic-env.tpl", {
      restic_repository  = var.restic_repository
      restic_password    = var.restic_password
      minio_access_key   = var.minio_access_key
      minio_secret_key   = var.minio_secret_key
    })
    destination = "/etc/restic.env"

    connection {
      type        = "ssh"
      user        = "root"
      password    = var.root_password
      host        = var.ip_address != "" ? var.ip_address : "127.0.0.1"
      agent       = false
    }
  }

  # Initialize restic repository
  provisioner "remote-exec" {
    inline = [
      "source /etc/restic.env && restic init || true",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      password    = var.root_password
      host        = var.ip_address != "" ? var.ip_address : "127.0.0.1"
      timeout     = "5m"
      agent       = false
    }
  }

  # Create systemd service and timer
  provisioner "file" {
    content = templatefile("${path.module}/templates/restic-backup.service.tpl", {
      restic_repository = var.restic_repository
    })
    destination = "/etc/systemd/system/restic-backup.service"

    connection {
      type        = "ssh"
      user        = "root"
      password    = var.root_password
      host        = var.ip_address != "" ? var.ip_address : "127.0.0.1"
      agent       = false
    }
  }

  provisioner "file" {
    content     = file("${path.module}/templates/restic-backup.timer.tpl")
    destination = "/etc/systemd/system/restic-backup.timer"

    connection {
      type        = "ssh"
      user        = "root"
      password    = var.root_password
      host        = var.ip_address != "" ? var.ip_address : "127.0.0.1"
      agent       = false
    }
  }

  # Enable and start systemd timer
  provisioner "remote-exec" {
    inline = [
      "systemctl daemon-reload",
      "systemctl enable restic-backup.timer",
      "systemctl start restic-backup.timer",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      password    = var.root_password
      host        = var.ip_address != "" ? var.ip_address : "127.0.0.1"
      timeout     = "5m"
      agent       = false
    }
  }
}
