output "talos_config" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "control_plane_ip" {
  description = "Control plane IP address"
  value       = var.control_plane.ip
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = [for w in var.workers : w.ip]
}

output "truenas_ip" {
  description = "TrueNAS IP address"
  value       = var.truenas_vm.ip
}

output "cluster_info" {
  description = "Cluster information"
  value = {
    control_plane_ip = var.control_plane.ip
    worker_ips      = [for w in var.workers : w.ip]
    truenas_ip      = var.truenas_vm.ip
    vm_ids = {
      control_plane = local.vm_ids.control_plane
      workers       = local.vm_ids.workers
      truenas       = local.vm_ids.truenas
    }
    storage_pools = {
      vms      = var.proxmox_storage
      longhorn = var.proxmox_longhorn_storage
      truenas  = var.proxmox_truenas_storage
    }
  }
}
