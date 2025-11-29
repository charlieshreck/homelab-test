output "lxc_id" {
  value       = proxmox_virtual_environment_lxc.restic_lxc.vm_id
  description = "Proxmox VM ID of the Restic LXC"
}

output "lxc_name" {
  value       = proxmox_virtual_environment_lxc.restic_lxc.hostname
  description = "Hostname of the Restic LXC"
}

output "lxc_ip" {
  value       = var.ip_address != "" ? var.ip_address : "DHCP"
  description = "IP address of the Restic LXC"
}
