output "lxc_id" {
  value       = proxmox_virtual_environment_container.restic_lxc.vm_id
  description = "Proxmox VM ID of the Restic LXC"
}

output "lxc_hostname" {
  value       = var.vm_name
  description = "Hostname of the Restic LXC"
}

output "lxc_ip" {
  value       = var.ip_address != "" ? var.ip_address : "DHCP"
  description = "IP address of the Restic LXC"
}
