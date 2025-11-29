#!/bin/bash
set -e

echo "Initializing Plex LXC container..."

# Update package manager
apt-get update
apt-get install -y \
  curl \
  wget \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker service
systemctl enable docker
systemctl start docker

# Create directories for Plex
mkdir -p /opt/plex/config
mkdir -p /mnt/media

# Create docker-compose.yml for Plex stack
cat > /opt/plex/docker-compose.yml << 'EOF'
version: '3.8'

services:
  plex:
    image: lscr.io/linuxserver/plex:2.0.1
    container_name: plex
    network_mode: host
    environment:
      - PUID=1000
      - PGID=1000
      - VERSION=latest
      - PLEX_CLAIM=${plex_claim_token}
      - ADVERTISE_IP=http://10.10.0.60:32400
    volumes:
      - /opt/plex/config:/config
      - /mnt/media:/mnt/media
    devices:
      - /dev/dri:/dev/dri
    restart: unless-stopped
    labels:
      - "com.example.description=Plex Media Server"

  watchtower:
    image: containrrr/watchtower:1.7.1
    container_name: watchtower-plex
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400 --label-enable plex watchtower-plex
    restart: unless-stopped

  tautulli:
    image: lscr.io/linuxserver/tautulli:2.14.5
    container_name: tautulli
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - /opt/plex/tautulli:/config
      - /opt/plex/config/Library/Logs:/logs:ro
    ports:
      - "8181:8181"
    restart: unless-stopped
    labels:
      - "com.example.description=Plex statistics and monitoring"
EOF

# Deploy Plex stack
cd /opt/plex
docker compose up -d

echo "Plex container initialization complete!"
