#!/bin/bash
set -euo pipefail

LINES="${1:-30}"

echo "=== BACKUP SERVICE LOGS (last $LINES lines) ==="
echo ""
journalctl -u p1-backup.service -n "$LINES" --no-pager

echo ""
echo "=== LAST BACKUP TIMER RUN ==="
systemctl status p1-backup.timer --no-pager -l || true

echo ""
echo "=== NEXT SCHEDULED BACKUP ==="
systemctl list-timers p1-backup.timer --no-pager || true

echo ""
echo "=== BACKUP FILES ON DISK ==="
BACKUP_DIR="/var/backups/P1"
if [[ -d "$BACKUP_DIR" ]]; then
    ls -lht "$BACKUP_DIR" | head -n 10
    echo ""
    echo "Total: $(du -sh "$BACKUP_DIR" | cut -f1)"
else
    echo "No backup directory found at $BACKUP_DIR"
fi
