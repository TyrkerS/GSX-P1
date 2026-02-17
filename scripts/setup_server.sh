#!/bin/bash
set -euo pipefail

USER_NAME="gsx"
BASE_DIR="/opt/P1"

# --------------------------------------------------
# Comprovacio root
# --------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Use: su -  OR  sudo ./bootstrap.sh"
  exit 1
fi

log() {
    echo
    echo "==> $1"
}

update_system() {
    log "Updating package index..."
    apt update -y
}

install_packages() {
    log "Installing required packages..."
    apt install -y \
        sudo \
        openssh-server \
        git \
        vim \
        curl \
        htop \
        tree
}

configure_sudo() {
    log "Ensuring user has sudo privileges..."

    if ! id -nG "$USER_NAME" | grep -qw sudo; then
        /usr/sbin/usermod -aG sudo "$USER_NAME"
        echo "User added to sudo group."
    else
        echo "User already in sudo group."
    fi
}

configure_ssh() {
    log "Configuring SSH service..."

    systemctl enable ssh
    systemctl start ssh

    # Harden SSH configuration
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    systemctl restart ssh
}

create_structure() {
    log "Creating administrative directory structure..."

    mkdir -p "$BASE_DIR"/{scripts,backups,logs,docs}
    chown -R "$USER_NAME":"$USER_NAME" "$BASE_DIR"
}

main() {
    log "Starting GreenDevCorp Week 1 bootstrap..."

    update_system
    install_packages
    configure_sudo
    configure_ssh
    create_structure

    log "Bootstrap completed successfully."
}

main
