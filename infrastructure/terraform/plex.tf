# ==============================================================================
# Plex Media Server LXC Container with AMD 680M GPU Passthrough
# ==============================================================================
# This deploys a privileged LXC container with:
# - AMD Radeon 680M iGPU passthrough for hardware transcoding
# - Dual NICs (management + storage network for TrueNAS NFS)
# - Restic backups to MinIO
# - Docker-based Plex with VAAPI support
# ==============================================================================

module "plex" {
  source = "./modules/plex-lxc"

  proxmox_node = var.proxmox_node
  vm_id        = 220
  hostname     = "plex"

  # Network configuration matching existing architecture
  management_ip    = "10.10.0.60"
  media_network_ip = "10.11.0.60" # Storage network for TrueNAS NFS
  gateway          = var.prod_gateway

  management_bridge = var.network_bridge # vmbr0
  media_bridge      = var.storage_bridge # vmbr1

  cpu_cores    = 4
  memory_mb    = 8192
  disk_size_gb = 100
  storage_pool = var.proxmox_storage

  ssh_public_keys = var.ssh_public_keys
}

# Configure GPU passthrough after container creation
resource "null_resource" "plex_gpu_config" {
  depends_on = [module.plex]

  provisioner "local-exec" {
    command = <<-EOT
      # Copy GPU config script to Proxmox host
      scp ${path.module}/../scripts/configure-plex-gpu.sh root@${var.proxmox_host}:/tmp/

      # Execute GPU config script on Proxmox host
      ssh root@${var.proxmox_host} 'bash /tmp/configure-plex-gpu.sh ${module.plex.container_id}'
    EOT
  }

  triggers = {
    container_id = module.plex.container_id
  }
}

# Run Ansible after GPU is configured
resource "null_resource" "plex_ansible" {
  depends_on = [null_resource.plex_gpu_config]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for container to be fully ready
      sleep 30

      # Run Ansible playbook
      cd ${path.module}/../ansible
      ansible-playbook -i inventory/plex.yml playbooks/plex.yml
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

output "plex_info" {
  description = "Plex deployment information"
  value = {
    container_id     = module.plex.container_id
    management_ip    = module.plex.management_ip
    media_network_ip = module.plex.media_network_ip
    web_ui           = "http://${module.plex.management_ip}:32400/web"
  }
}
