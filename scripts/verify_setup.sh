#!/bin/bash
set -euo pipefail

USER_NAME="gsx"
BASE_DIR="/opt/P1"
ERRORS=0

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

check "SSH service is running" systemctl is-active --quiet ssh

check "Root login disabled" grep -q '^PermitRootLogin no' /etc/ssh/sshd_config
check "Password authentication disabled" grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config
check "Public key authentication enabled" grep -q '^PubkeyAuthentication yes' /etc/ssh/sshd_config

check "User is in sudo group" bash -c "id -nG $USER_NAME | grep -qw sudo"

check "Scripts directory exists" test -d "$BASE_DIR/scripts"
check "Backups directory exists" test -d "$BASE_DIR/backups"
check "Logs directory exists" test -d "$BASE_DIR/logs"
check "Docs directory exists" test -d "$BASE_DIR/docs"

echo
if [ "$ERRORS" -eq 0 ]; then
    echo "=== Verification Successful ==="
    exit 0
else
    echo "=== Verification Failed: $ERRORS error(s) detected ==="
    exit 1
fi
