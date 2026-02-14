#!/bin/bash
set -euo pipefail

USER_NAME="gsx"
BASE_DIR="/opt/greendevcorp"

echo "[1] Updating system..."
sudo apt update

echo "[2] Installing required packages..."
sudo apt install -y \
    sudo \
    openssh-server \
    git \
    vim \
    curl \
    htop \
    tree

echo "[3] Ensuring user is in sudo group..."
if ! id -nG "$USER_NAME" | grep -qw sudo; then
    sudo usermod -aG sudo "$USER_NAME"
    echo "User added to sudo group."
else
    echo "User already in sudo group."
fi

echo "[4] Enabling and starting SSH..."
sudo systemctl enable ssh
sudo systemctl restart ssh

echo "[5] Hardening SSH configuration..."
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

sudo systemctl restart ssh

echo "[6] Creating administrative directory structure..."
sudo mkdir -p $BASE_DIR/{scripts,backups,logs,docs}
sudo chown -R "$USER_NAME":"$USER_NAME" $BASE_DIR

echo "=== Bootstrap Complete ==="
