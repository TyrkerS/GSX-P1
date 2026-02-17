#!/bin/bash
set -euo pipefail

log() { echo; echo "==> $1"; }

# --- Detect project root based on this script location ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"          # .../P1
SYSTEMD_DIR="$PROJECT_ROOT/systemd"                      # templates for Git

BACKUPS_DIR="$PROJECT_ROOT/backups"
LOGS_DIR="$PROJECT_ROOT/logs"
DOCS_DIR="$PROJECT_ROOT/docs"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

BACKUP_SCRIPT="$SCRIPTS_DIR/backup.sh"

BACKUP_SERVICE_NAME="p1-backup.service"
BACKUP_TIMER_NAME="p1-backup.timer"

BACKUP_SERVICE_PATH="/etc/systemd/system/$BACKUP_SERVICE_NAME"
BACKUP_TIMER_PATH="/etc/systemd/system/$BACKUP_TIMER_NAME"

NGINX_OVERRIDE_DIR="/etc/systemd/system/nginx.service.d"
NGINX_OVERRIDE_FILE="$NGINX_OVERRIDE_DIR/override.conf"

require_sudo() {
  if ! sudo -v; then
    echo "Need sudo privileges."
    exit 1
  fi
}

ensure_repo_dirs() {
  log "Ensuring project directories exist under: $PROJECT_ROOT"
  mkdir -p "$BACKUPS_DIR" "$LOGS_DIR" "$DOCS_DIR" "$SYSTEMD_DIR"
  mkdir -p "$SCRIPTS_DIR"
}

install_packages() {
  log "Installing required packages (nginx, etc.)..."
  sudo apt update
  sudo apt install -y nginx
}

enable_nginx_boot() {
  log "Enabling Nginx on boot..."
  sudo systemctl enable nginx
}

configure_nginx_autorestart() {
  log "Configuring Nginx auto-restart (systemd override drop-in)..."
  sudo mkdir -p "$NGINX_OVERRIDE_DIR"
  sudo tee "$NGINX_OVERRIDE_FILE" >/dev/null <<'EOF'
[Service]
Restart=on-failure
RestartSec=2s
EOF

  sudo systemctl daemon-reload
  sudo systemctl restart nginx
}

create_backup_script() {
  log "Creating backup script (idempotent)..."

  if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    cat >"$BACKUP_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail

# Backup the project root (P1) into backups/
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SRC="$PROJECT_ROOT"
DEST="$PROJECT_ROOT/backups"
TS="$(date +"%Y-%m-%d_%H-%M-%S")"
OUT="$DEST/backup_${TS}.tar.gz"

mkdir -p "$DEST"
tar -czf "$OUT" "$SRC"
echo "Backup created: $OUT"
EOF
  fi

  chmod +x "$BACKUP_SCRIPT"
}

write_systemd_templates_into_repo() {
  log "Writing systemd unit templates into repo (to commit to Git)..."

  cat >"$SYSTEMD_DIR/$BACKUP_SERVICE_NAME" <<EOF
[Unit]
Description=GreenDevCorp P1 Backup (Week 2)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$BACKUP_SCRIPT
EOF

  cat >"$SYSTEMD_DIR/$BACKUP_TIMER_NAME" <<'EOF'
[Unit]
Description=Run GreenDevCorp P1 backup daily (Week 2)

[Timer]
OnCalendar=daily
Persistent=true
AccuracySec=5m

[Install]
WantedBy=timers.target
EOF
}

install_systemd_units() {
  log "Installing systemd service + timer into /etc/systemd/system/ ..."

  sudo cp "$SYSTEMD_DIR/$BACKUP_SERVICE_NAME" "$BACKUP_SERVICE_PATH"
  sudo cp "$SYSTEMD_DIR/$BACKUP_TIMER_NAME" "$BACKUP_TIMER_PATH"

  sudo systemctl daemon-reload
  sudo systemctl enable --now "$BACKUP_TIMER_NAME"
}

create_observability_scripts() {
  log "Creating observability scripts in repo..."

  cat >"$SCRIPTS_DIR/status-week2.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "== Nginx =="
systemctl --no-pager --full status nginx || true
echo
echo "== Backup service (last run) =="
systemctl --no-pager --full status p1-backup.service || true
echo
echo "== Timers =="
systemctl list-timers --all | grep -E 'p1-backup|NEXT|LEFT|LAST|PASSED|UNIT|ACTIVATES' || true
echo
echo "== Journald disk usage =="
journalctl --disk-usage || true
EOF
  chmod +x "$SCRIPTS_DIR/status-week2.sh"

  cat >"$SCRIPTS_DIR/show-nginx-logs.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
journalctl -u nginx --since "24 hours ago" --no-pager
EOF
  chmod +x "$SCRIPTS_DIR/show-nginx-logs.sh"

  cat >"$SCRIPTS_DIR/show-backup-logs.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
journalctl -u p1-backup.service --since "7 days ago" --no-pager
EOF
  chmod +x "$SCRIPTS_DIR/show-backup-logs.sh"
}

optional_limit_journald() {
  log "Optional: limiting journald growth (safe defaults)..."
  local conf="/etc/systemd/journald.conf"

  sudo cp -n "$conf" "${conf}.bak" 2>/dev/null || true
  sudo sed -i 's/^\s*#\?\s*SystemMaxUse\s*=.*/SystemMaxUse=200M/' "$conf"
  sudo sed -i 's/^\s*#\?\s*SystemKeepFree\s*=.*/SystemKeepFree=100M/' "$conf"
  sudo sed -i 's/^\s*#\?\s*MaxRetentionSec\s*=.*/MaxRetentionSec=1month/' "$conf"

  sudo systemctl restart systemd-journald
}

verify_everything() {
  log "Verification..."

  echo "-- nginx enabled? --"
  systemctl is-enabled nginx || true
  echo "-- nginx active? --"
  systemctl is-active nginx || true

  echo
  echo "-- backup timer enabled/active? --"
  systemctl is-enabled "$BACKUP_TIMER_NAME" || true
  systemctl is-active "$BACKUP_TIMER_NAME" || true

  echo
  echo "-- running backup once (manual test) --"
  sudo systemctl start "$BACKUP_SERVICE_NAME"
  sudo systemctl status "$BACKUP_SERVICE_NAME" --no-pager || true

  echo
  echo "-- backups directory --"
  ls -lh "$BACKUPS_DIR" || true

  echo
  echo "Useful scripts:"
  echo "  $SCRIPTS_DIR/status-week2.sh"
  echo "  $SCRIPTS_DIR/show-nginx-logs.sh"
  echo "  $SCRIPTS_DIR/show-backup-logs.sh"
}

main() {
  require_sudo
  ensure_repo_dirs
  install_packages
  enable_nginx_boot
  configure_nginx_autorestart
  create_backup_script
  write_systemd_templates_into_repo
  install_systemd_units
  create_observability_scripts
  optional_limit_journald

  verify_everything

  log "Week 2 setup completed."
  echo "PROJECT_ROOT: $PROJECT_ROOT"
  echo "Systemd templates saved in: $SYSTEMD_DIR (commit these to Git)"
}

main

