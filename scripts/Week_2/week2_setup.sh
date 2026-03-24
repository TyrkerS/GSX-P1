#!/bin/bash
set -euo pipefail

# --------------------------------------------------
# Configuració
# --------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
SYSTEMD_REPO_DIR="$PROJECT_ROOT/systemd"

BACKUP_SERVICE_NAME="p1-backup.service"
BACKUP_TIMER_NAME="p1-backup.timer"

BACKUP_SERVICE_SRC="$SYSTEMD_REPO_DIR/$BACKUP_SERVICE_NAME"
BACKUP_TIMER_SRC="$SYSTEMD_REPO_DIR/$BACKUP_TIMER_NAME"

BACKUP_SERVICE_DEST="/etc/systemd/system/$BACKUP_SERVICE_NAME"
BACKUP_TIMER_DEST="/etc/systemd/system/$BACKUP_TIMER_NAME"

NGINX_OVERRIDE_DIR="/etc/systemd/system/nginx.service.d"
NGINX_OVERRIDE_FILE="$NGINX_OVERRIDE_DIR/override.conf"

# --------------------------------------------------
# Comprovació root
# --------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Use: sudo ./bootstrap_week2.sh"
  exit 1
fi

log() {
    echo
    echo "==> $1"
}

# --------------------------------------------------
# Instal·lació de paquets
# --------------------------------------------------

install_packages() {
    log "Installing required packages (nginx, logrotate)..."
    apt update
    apt install -y nginx logrotate
}

# --------------------------------------------------
# Configurar Nginx
# --------------------------------------------------

configure_nginx() {
    log "Enabling Nginx at boot..."
    systemctl enable nginx
    systemctl start nginx
}

configure_nginx_autorestart() {
    log "Configuring Nginx auto-restart policy..."

    mkdir -p "$NGINX_OVERRIDE_DIR"

    cat > "$NGINX_OVERRIDE_FILE" <<'EOF'
[Service]
Restart=on-failure
RestartSec=5s
EOF

    systemctl daemon-reload
    systemctl restart nginx
}

# --------------------------------------------------
# Instal·lar systemd units (backup service + timer)
# --------------------------------------------------

install_systemd_units() {
    log "Installing backup service and timer..."

    if [[ ! -f "$BACKUP_SERVICE_SRC" ]]; then
        echo "Missing $BACKUP_SERVICE_SRC"
        exit 1
    fi

    if [[ ! -f "$BACKUP_TIMER_SRC" ]]; then
        echo "Missing $BACKUP_TIMER_SRC"
        exit 1
    fi

    cp "$BACKUP_SERVICE_SRC" "$BACKUP_SERVICE_DEST"
    cp "$BACKUP_TIMER_SRC"   "$BACKUP_TIMER_DEST"

    # Patch ExecStart with the actual backup script path (repo may not be at /opt/P1)
    BACKUP_SCRIPT="$PROJECT_ROOT/scripts/Week_5_backup/backup.sh"
    if [[ -f "$BACKUP_SCRIPT" ]]; then
        sed -i "s|ExecStart=.*|ExecStart=$BACKUP_SCRIPT|" "$BACKUP_SERVICE_DEST"
        echo "ExecStart patched to: $BACKUP_SCRIPT"
    fi

    # Remove RequiresMountsFor if /mnt/storage doesn't exist yet (Week 5 disk optional)
    if ! mountpoint -q /mnt/storage 2>/dev/null; then
        sed -i '/^RequiresMountsFor/d' "$BACKUP_SERVICE_DEST"
        echo "RequiresMountsFor removed (no storage disk yet — will backup to /var/backups/P1)"
    fi

    systemctl daemon-reload
    systemctl enable "$BACKUP_TIMER_NAME"
    systemctl start  "$BACKUP_TIMER_NAME"
}

# --------------------------------------------------
# Verificació bàsica
# --------------------------------------------------

verify_services() {
    log "Verifying services..."

    echo "-- Nginx status --"
    systemctl is-enabled nginx
    systemctl is-active nginx

    echo
    echo "-- Backup timer status --"
    systemctl is-enabled "$BACKUP_TIMER_NAME"
    systemctl is-active "$BACKUP_TIMER_NAME"

    echo
    echo "-- Active timers --"
    systemctl list-timers --all | grep "$BACKUP_TIMER_NAME" || true
}

# --------------------------------------------------
# Configurar journald (límits de logs)
# --------------------------------------------------

configure_journald() {
    log "Configuring journald log limits..."

    local CONF_DIR="/etc/systemd/journald.conf.d"
    local CONF_FILE="$CONF_DIR/limits.conf"

    mkdir -p "$CONF_DIR"

    # Idempotent: only write if not already configured
    if [[ ! -f "$CONF_FILE" ]]; then
        cat > "$CONF_FILE" << 'EOF'
[Journal]
# Limit total journal disk usage
SystemMaxUse=200M
# Keep each individual journal file small
SystemMaxFileSize=20M
# Delete logs older than 30 days
MaxRetentionSec=30day
# Compress journal files
Compress=yes
EOF
        echo "journald limits config written to $CONF_FILE"
    else
        echo "journald limits config already exists — skipping."
    fi

    systemctl restart systemd-journald
}

# --------------------------------------------------
# MAIN
# --------------------------------------------------

main() {
    log "Starting Week 2 setup..."

    install_packages
    configure_nginx
    configure_nginx_autorestart
    install_systemd_units
    configure_journald
    verify_services

    log "Week 2 setup completed successfully."
}

main