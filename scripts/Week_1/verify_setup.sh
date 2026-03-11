#!/bin/bash
set -euo pipefail

USER_NAME="gsx"
BASE_DIR="/opt/P1"
BACKUP_DIR="/var/backups/P1"
ETC_DIR="/etc/P1"
SSH_PORT="22222"

ERRORS=0

echo
echo "=== Week 1 Verification Script ==="
echo

check() {
    description="$1"
    shift

    if "$@"; then
        echo "[OK] $description"
    else
        echo "[ERROR] $description"
        ERRORS=$((ERRORS+1))
    fi
}

# ------------------------------
# SSH checks
# ------------------------------
check "SSH service is running" systemctl is-active --quiet ssh
check "SSH service enabled at boot" systemctl is-enabled --quiet ssh

check "SSH port is set correctly" grep -q "^Port $SSH_PORT" /etc/ssh/sshd_config
check "Root login disabled" grep -q '^PermitRootLogin no' /etc/ssh/sshd_config
check "Password authentication disabled" grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config
check "Public key authentication enabled" grep -q '^PubkeyAuthentication yes' /etc/ssh/sshd_config

# ------------------------------
# Sudo check
# ------------------------------
check "User is in sudo group" bash -c "id -nG $USER_NAME | grep -qw sudo"

# ------------------------------
# Automatic updates
# ------------------------------
check "unattended-upgrades installed" dpkg -l unattended-upgrades
check "unattended-upgrades service active" systemctl is-active --quiet unattended-upgrades

# ------------------------------
# Directory structure
# ------------------------------
check "Base directory exists" test -d "$BASE_DIR"
check "Scripts directory exists" test -d "$BASE_DIR/scripts"
check "Docs directory exists" test -d "$BASE_DIR/docs"
check "Logs directory exists" test -d "$BASE_DIR/logs"

check "Backup directory exists" test -d "$BACKUP_DIR"
check "ETC config directory exists" test -d "$ETC_DIR"

# ------------------------------
# Git repository check
# ------------------------------
check "Git repository initialized" test -d "$BASE_DIR/.git"

check "Baseline commit exists" bash -c "cd $BASE_DIR && git log --oneline | grep -q 'Baseline administrative structure'"

# ------------------------------
# Final result
# ------------------------------
echo
if [ "$ERRORS" -eq 0 ]; then
    echo "=== Verification Successful ==="
    exit 0
else
    echo "=== Verification Failed: $ERRORS error(s) detected ==="
    exit 1
fi