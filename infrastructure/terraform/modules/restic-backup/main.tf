# ==============================================================================
# Restic Backup Module for LXC/VMs
# ==============================================================================

# Install Restic on target host
resource "null_resource" "install_restic" {
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y restic",
      "restic version"
    ]

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }
}

# Create restic environment configuration file
resource "null_resource" "deploy_restic_env" {
  depends_on = [null_resource.install_restic]

  provisioner "file" {
    content = templatefile("${path.module}/templates/restic-env.tpl", {
      repository       = var.restic_repository
      password         = var.restic_password
      aws_access_key   = var.aws_access_key
      aws_secret_key   = var.aws_secret_key
    })
    destination = "/tmp/restic-env"

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mv /tmp/restic-env /etc/restic-env",
      "chmod 600 /etc/restic-env",
      "chown root:root /etc/restic-env"
    ]

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }
}

# Deploy backup script
resource "null_resource" "deploy_backup_script" {
  depends_on = [null_resource.deploy_restic_env]

  provisioner "file" {
    content = templatefile("${path.module}/templates/backup.sh.tpl", {
      backup_paths     = join(" ", var.backup_paths)
      backup_excludes  = join(" ", [for p in var.backup_excludes : "--exclude ${p}"])
      retention_daily  = var.retention_daily
      retention_weekly = var.retention_weekly
      retention_monthly = var.retention_monthly
      health_check_url = var.health_check_url
    })
    destination = "/tmp/restic-backup.sh"

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mv /tmp/restic-backup.sh /usr/local/bin/restic-backup.sh",
      "chmod 755 /usr/local/bin/restic-backup.sh"
    ]

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }
}

# Deploy systemd service unit
resource "null_resource" "deploy_service" {
  depends_on = [null_resource.deploy_backup_script]

  provisioner "file" {
    content = templatefile("${path.module}/templates/restic-backup.service.tpl", {
      container_name = var.container_name
    })
    destination = "/tmp/restic-backup.service"

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mv /tmp/restic-backup.service /etc/systemd/system/restic-backup.service",
      "systemctl daemon-reload"
    ]

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }
}

# Deploy systemd timer unit
resource "null_resource" "deploy_timer" {
  depends_on = [null_resource.deploy_service]

  provisioner "file" {
    content = templatefile("${path.module}/templates/restic-backup.timer.tpl", {
      container_name = var.container_name
      schedule_time  = "${var.schedule_hour}:${format("%02d", var.schedule_minute)}"
    })
    destination = "/tmp/restic-backup.timer"

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mv /tmp/restic-backup.timer /etc/systemd/system/restic-backup.timer",
      "systemctl daemon-reload",
      "systemctl enable restic-backup.timer",
      "systemctl start restic-backup.timer"
    ]

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }
}

# Initialize restic repository
resource "null_resource" "init_repository" {
  depends_on = [null_resource.deploy_timer]

  provisioner "remote-exec" {
    inline = [
      "source /etc/restic-env",
      "restic cat config > /dev/null 2>&1 || restic init",
      "echo 'Repository initialization complete'"
    ]

    connection {
      type     = "ssh"
      user     = var.host_user
      password = var.host_password != "" ? var.host_password : null
      private_key = try(file(var.ssh_key_path), null)
      host     = var.host
    }
  }
}
