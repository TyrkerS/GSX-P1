#!/bin/bash
set -euo pipefail

ERRORS=0

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

echo
echo "=== Week 2 Verification ==="
echo


# NGINX
check "Nginx installed" command -v nginx
check "Nginx enabled at boot" systemctl is-enabled nginx
check "Nginx active" systemctl is-active nginx

check "Nginx restart policy configured" \
    grep -q "Restart=on-failure" /etc/systemd/system/nginx.service.d/override.conf

