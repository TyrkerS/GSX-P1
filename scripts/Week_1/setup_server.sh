#!/bin/bash
set -euo pipefail

USER_NAME="gsx"
BASE_DIR="/opt/P1"
BACKUP_DIR="/var/backups/P1"
ETC_DIR="/etc/P1"
SSH_PORT="22222"


# Root check
if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: su - OR sudo ./bootstrap.sh"
  exit 1
fi

log() {
    echo
    echo "==> $1"
}

# System update
update_system() {
    log "Updating system..."
    apt update -y
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    apt install -y \
        sudo \
        openssh-server \
        vim \
        curl \
        htop \
        tree \
        unattended-upgrades
}

# Configure automatic updates
configure_auto_updates() {
    log "Enabling automatic security updates..."
    dpkg-reconfigure -f noninteractive unattended-upgrades
}

# Configure sudo
configure_sudo() {
    log "Configuring sudo..."

    if ! id -nG "$USER_NAME" | grep -qw sudo; then
        /usr/sbin/usermod -aG sudo "$USER_NAME"
        echo "User added to sudo group."
    fi
}

# Configure SSH
configure_ssh() {
    log "Configuring SSH..."

    systemctl enable ssh
    systemctl start ssh

    # Harden SSH
    sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    systemctl restart ssh
}

# Create directory structure
create_structure() {
    log "Creating directory structure..."

    mkdir -p "$BASE_DIR/scripts"
    mkdir -p "$BASE_DIR/docs"
    mkdir -p "$BASE_DIR/logs"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$ETC_DIR"

    chown -R "$USER_NAME":"$USER_NAME" "$BASE_DIR"
    chown -R "$USER_NAME":"$USER_NAME" "$BACKUP_DIR"
}


# Initialize Git repository
initialize_git() {
    log "Initializing Git repository in $BASE_DIR"

    cd "$BASE_DIR"

    if [ ! -d ".git" ]; then
        git init
        git config user.name "GreenDevCorp Admin"
        git config user.email "admin@greendevcorp.local"

        touch .gitignore
        echo "*.log" >> .gitignore
        echo "backups/" >> .gitignore

        git add .
        git commit -m "Baseline administrative structure"
    fi
}


# Main
main() {
    log "Starting Week 1 bootstrap..."

    update_system
    install_packages
    configure_auto_updates
    configure_sudo
    configure_ssh
    create_structure
    initialize_git

    log "Bootstrap completed successfully."
}

main