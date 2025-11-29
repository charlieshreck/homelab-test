[Unit]
Description=Restic Backup Timer for ${container_name}
Requires=restic-backup.service

[Timer]
OnCalendar=daily
OnCalendar=${schedule_time}
Persistent=true
Unit=restic-backup.service

[Install]
WantedBy=timers.target
