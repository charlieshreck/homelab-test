output "container_id" {
  description = "Plex container ID"
  value       = proxmox_virtual_environment_container.plex.vm_id
}

output "management_ip" {
  description = "Management network IP"
  value       = var.management_ip
}

output "media_network_ip" {
  description = "Media network IP"
  value       = var.media_network_ip
}

output "hostname" {
  description = "Container hostname"
  value       = var.hostname
}
