output "backup_host" {
  description = "The host configured for backups"
  value       = var.host
}

output "backup_repository" {
  description = "The Restic repository configured"
  value       = var.restic_repository
}

output "backup_schedule" {
  description = "Cron schedule for backups"
  value       = "${var.schedule_minute} ${var.schedule_hour} * * *"
}

output "backup_paths" {
  description = "Paths being backed up"
  value       = var.backup_paths
}
