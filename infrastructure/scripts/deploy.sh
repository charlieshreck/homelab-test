#!/bin/bash

# Debian 12 LXC Configuration Script
# This script configures SSH root login, updates the system, and installs Terraform

set -e  # Exit on any error

echo "=== Debian 12 LXC Configuration Script ==="
echo "Starting configuration..."

# Update package lists and upgrade system
echo "Updating package lists and upgrading system..."
apt update
apt upgrade -y

# Install essential packages
echo "Installing essential packages..."
apt install -y \
    openssh-server \
    curl \
    wget \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    unzip \
    jq

# Configure SSH for root password login
echo "Configuring SSH for root password authentication..."

# Backup original SSH config if not already backed up
if [ ! -f /etc/ssh/sshd_config.backup ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    echo "SSH config backed up"
else
    echo "SSH config backup already exists, skipping"
fi

# Configure SSH settings
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Ensure SSH is enabled and started
systemctl enable ssh
systemctl restart ssh

# Set root password if not already set
if [ ! -f /root/.password_set ]; then
    echo "Setting root password..."
    echo "Please set a secure root password:"
    passwd root
    touch /root/.password_set
else
    echo "Root password already configured, skipping"
fi

# Install Terraform
echo "Installing Terraform..."

if ! command -v terraform &> /dev/null; then
    # Add HashiCorp GPG key
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

    # Add HashiCorp repository
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

    # Update package list and install Terraform
    apt update
    apt install -y terraform
    echo "Terraform installed"
else
    echo "Terraform already installed: $(terraform version | head -1)"
fi

# Generate age key for SOPS
echo "Setting up age encryption key for SOPS..."

if [ ! -f /root/.age-key.txt ]; then
    # Install age if not present
    if ! command -v age-keygen &> /dev/null; then
        echo "Installing age..."
        wget -q https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz -O /tmp/age.tar.gz
        tar -xzf /tmp/age.tar.gz -C /tmp/
        mv /tmp/age/age* /usr/local/bin/
        chmod +x /usr/local/bin/age*
        rm -rf /tmp/age.tar.gz /tmp/age
        echo "Age installed"
    fi

    # Generate age key
    echo "Generating new age key..."
    age-keygen -o /root/.age-key.txt

    # Extract public key
    AGE_PUBLIC_KEY=$(grep "public key:" /root/.age-key.txt | cut -d: -f2 | tr -d ' ')

    # Create .env file for Terraform
    cat > /root/.sops.env <<EOF
AGE_PRIVATE_KEY=$(cat /root/.age-key.txt)
AGE_PUBLIC_KEY=${AGE_PUBLIC_KEY}
EOF

    chmod 600 /root/.age-key.txt
    chmod 600 /root/.sops.env

    echo "Age key generated and saved"
    echo "Public key: ${AGE_PUBLIC_KEY}"
else
    echo "Age key already exists at /root/.age-key.txt"
    # Recreate .env if missing but key exists
    if [ ! -f /root/.sops.env ]; then
        AGE_PUBLIC_KEY=$(grep "public key:" /root/.age-key.txt | cut -d: -f2 | tr -d ' ')
        cat > /root/.sops.env <<EOF
AGE_PRIVATE_KEY=$(cat /root/.age-key.txt)
AGE_PUBLIC_KEY=${AGE_PUBLIC_KEY}
EOF
        chmod 600 /root/.sops.env
        echo ".sops.env file recreated"
    fi
fi

# Install SOPS
echo "Installing SOPS..."
if ! command -v sops &> /dev/null; then
    wget -q https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64 -O /usr/local/bin/sops
    chmod +x /usr/local/bin/sops
    echo "SOPS installed"
else
    echo "SOPS already installed: $(sops --version)"
fi

# Clean up
echo "Cleaning up..."
apt autoremove -y
apt autoclean

# Display network information
echo "=== Configuration Complete ==="
echo "Network interfaces:"
ip addr show

echo ""
echo "SSH Configuration:"
echo "- Root login via password: ENABLED"
echo "- SSH service: $(systemctl is-active ssh)"
echo "- SSH port: $(grep -E '^#?Port' /etc/ssh/sshd_config | head -1 | awk '{print $2}' || echo '22')"

echo ""
echo "Installed versions:"
echo "- Debian: $(cat /etc/debian_version)"
echo "- Terraform: $(terraform version -json | jq -r '.terraform_version')"
echo "- Age: $(age --version 2>&1 || echo 'installed')"
echo "- SOPS: $(sops --version)"
echo "- jq: $(jq --version)"

echo ""
echo "Age Key Information:"
if [ -f /root/.sops.env ]; then
    echo "- Private key: /root/.age-key.txt"
    echo "- Environment file: /root/.sops.env"
    echo "- Public key: $(grep AGE_PUBLIC_KEY /root/.sops.env | cut -d= -f2)"
fi

echo ""
echo "=== IMPORTANT SECURITY NOTES ==="
echo "1. Root password login is now enabled - ensure you use a strong password"
echo "2. Consider setting up SSH key authentication for better security"
echo "3. Configure firewall rules if needed"
echo "4. Regular security updates are recommended"
echo "5. Age private key is stored in /root/.age-key.txt - KEEP THIS SAFE"
echo "6. Source .sops.env in your shell: source /root/.sops.env"

echo ""
echo "Configuration completed successfully!"
echo "You can now SSH to this container as root using: ssh root@<container-ip>"