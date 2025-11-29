[Unit]
Description=Restic Backup for ${container_name}
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
Group=root
ExecStart=/usr/local/bin/restic-backup.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=restic-backup

# Resource limits
MemoryLimit=1G
CPUQuota=50%

# Cleanup on failure
OnFailure=restic-backup-failure@%n.service

# Environment
EnvironmentFile=/etc/restic-env
