[Unit]
Description=Restic backup timer
Requires=restic-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
