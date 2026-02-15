#!/bin/bash
set -euo pipefail


USER_NAME="gsx"
BASE_DIR="/opt/P1"

log() {
    echo
    echo "==> $1"
}

update_system() {
    log "Updating package index..."
    sudo apt update -y
}

install_packages() {
    log "Installing required packages..."
    sudo apt install -y \
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
        sudo usermod -aG sudo "$USER_NAME"
        echo "User added to sudo group."
    else
        echo "User already in sudo group."
    fi
}

configure_ssh() {
    log "Configuring SSH service..."

    sudo systemctl enable ssh
    sudo systemctl start ssh

    # SSH configuration
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    sudo systemctl restart ssh
}

create_structure() {
    log "Creating administrative directory structure..."

    sudo mkdir -p "$BASE_DIR"/{scripts,backups,logs,docs}
    sudo chown -R "$USER_NAME":"$USER_NAME" "$BASE_DIR"
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
