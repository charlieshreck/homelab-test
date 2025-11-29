#!/bin/bash
# Restic backup script
# Performs incremental backup with retention policy enforcement

set -e

# Source environment configuration
if [ ! -f /etc/restic-env ]; then
  echo "ERROR: /etc/restic-env not found"
  exit 1
fi

source /etc/restic-env

LOGFILE="/var/log/restic-backup.log"
BACKUP_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log_message() {
  echo "[$BACKUP_TIMESTAMP] $1" | tee -a "$LOGFILE"
}

log_message "=== Starting Restic backup ==="

# Initialize repository if not already done
if ! restic cat config > /dev/null 2>&1; then
  log_message "Initializing repository..."
  restic init
fi

# Perform backup
log_message "Backing up: ${backup_paths}"
restic backup ${backup_paths} ${backup_excludes}

if [ $? -eq 0 ]; then
  log_message "Backup completed successfully"
else
  log_message "ERROR: Backup failed"
  exit 1
fi

# Apply retention policy
log_message "Applying retention policy (keep-daily: ${retention_daily}, keep-weekly: ${retention_weekly}, keep-monthly: ${retention_monthly})"
restic forget \
  --keep-daily ${retention_daily} \
  --keep-weekly ${retention_weekly} \
  --keep-monthly ${retention_monthly} \
  --prune

if [ $? -eq 0 ]; then
  log_message "Retention policy applied successfully"
else
  log_message "ERROR: Retention policy application failed"
  exit 1
fi

# Weekly integrity check (run on Sundays)
if [ "$(date +%u)" -eq 7 ]; then
  log_message "Running weekly integrity check..."
  if restic check; then
    log_message "Integrity check passed"
  else
    log_message "ERROR: Integrity check failed"
    exit 1
  fi
fi

# Health check report (if configured)
%{if health_check_url != ""}
if [ -n "${HEALTH_CHECK_URL}" ]; then
  log_message "Sending health check report..."
  curl -m 10 --retry 5 "${HEALTH_CHECK_URL}" > /dev/null 2>&1 || true
fi
%{endif}

log_message "=== Backup completed ==="
