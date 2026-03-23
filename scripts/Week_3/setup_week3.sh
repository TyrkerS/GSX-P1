#!/bin/bash
# setup_week3.sh — Configuració de Week 3
# Instal·la: paquets de monitoring, servei de demo workload
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
log "  systemd-cgtop -b -n 3                      # monitor CPU/MEM limits"
log "  sudo systemctl stop p1-workload.service    # stop the workload"
log ""
log "Or run demo scripts directly:"
log "  ./process_control_demo.sh                  # signal management demo"
log "  ./resource_limit_demo.sh                   # cgroup limits demo"
log ""
log "==> Week 3 configuration completed."
