output "container_id" {
  description = "The ID of the LXC container"
  value       = proxmox_virtual_environment_container.plex.vm_id
}

output "container_ip" {
  description = "The IP address of the Plex container"
  value       = var.ip_address
}

output "container_name" {
  description = "The name of the Plex container"
  value       = proxmox_virtual_environment_container.plex.name
}
