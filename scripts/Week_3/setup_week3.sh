#!/bin/bash
# setup_week3.sh — Install and enable Week 3 workload service.
# Copies p1-workload.service to /etc/systemd/system/ and reloads systemd.
# Also installs psmisc (needed by diagnose.sh for pstree).
#
# Usage: sudo ./setup_week3.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
SYSTEMD_SRC="$REPO_ROOT/systemd/p1-workload.service"
SYSTEMD_DEST="/etc/systemd/system/p1-workload.service"

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root." >&2; exit 1; }

log() { echo "==> $*"; }

# Install dependencies
log "Installing required packages (psmisc for pstree, sysstat for iostat)..."
apt-get update -qq
apt-get install -y psmisc sysstat

# Enforce execution bits (vital logic for fresh cloned installs)
log "Enforcing execution permissions securely..."
chmod +x "$SCRIPT_DIR"/*.sh

# Install workload service
log "Installing p1-workload.service..."
if [[ ! -f "$SYSTEMD_SRC" ]]; then
    echo "ERROR: Service file not found: $SYSTEMD_SRC" >&2
    exit 1
fi

cp "$SYSTEMD_SRC" "$SYSTEMD_DEST"
systemctl daemon-reload

log "Service installed: $SYSTEMD_DEST"
log ""
log "Usage:"
log "  sudo systemctl start p1-workload.service   # start the workload"
log "  systemd-cgtop -b -n 3                      # observe CPU/MEM limits"
log "  sudo systemctl stop p1-workload.service    # stop it"
log ""
log "Or run the demo scripts directly:"
log "  ./process_control_demo.sh                  # signal handling demo"
log "  ./resource_limit_demo.sh                   # cgroup limits demo"
log ""
log "==> Week 3 setup completed."
