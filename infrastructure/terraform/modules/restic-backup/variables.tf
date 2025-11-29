variable "host" {
  description = "Target host IP address or hostname"
  type        = string
}

variable "host_user" {
  description = "SSH user for connecting to the target host"
  type        = string
  default     = "root"
}

variable "host_password" {
  description = "SSH password for the target host (used if no SSH key)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_key_path" {
  description = "Path to SSH private key for authentication"
  type        = string
  default     = null
}

variable "container_name" {
  description = "Name identifier for this backup instance"
  type        = string
}

variable "restic_repository" {
  description = "Restic repository URL (e.g., s3:http://...)"
  type        = string
}

variable "restic_password" {
  description = "Restic repository encryption password"
  type        = string
  sensitive   = true
}

variable "aws_access_key" {
  description = "AWS/MinIO access key for S3 backend"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS/MinIO secret key for S3 backend"
  type        = string
  sensitive   = true
}

variable "backup_paths" {
  description = "List of paths to back up"
  type        = list(string)
  default     = ["/"]
}

variable "backup_excludes" {
  description = "List of patterns to exclude from backups"
  type        = list(string)
  default     = [
    ".cache",
    "*.tmp",
    "/proc",
    "/sys",
    "/dev",
    "/tmp",
  ]
}

variable "schedule_hour" {
  description = "Hour for scheduled backup (0-23)"
  type        = number
  default     = 2
}

variable "schedule_minute" {
  description = "Minute for scheduled backup (0-59)"
  type        = number
  default     = 0
}

variable "retention_daily" {
  description = "Number of daily backups to retain"
  type        = number
  default     = 7
}

variable "retention_weekly" {
  description = "Number of weekly backups to retain"
  type        = number
  default     = 4
}

variable "retention_monthly" {
  description = "Number of monthly backups to retain"
  type        = number
  default     = 12
}

variable "enable_health_check" {
  description = "Enable health check reports (e.g., Healthchecks.io)"
  type        = bool
  default     = false
}

variable "health_check_url" {
  description = "URL for health check reports"
  type        = string
  default     = ""
}
