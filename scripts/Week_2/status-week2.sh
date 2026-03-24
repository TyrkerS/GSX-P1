#!/bin/bash
# status-week2.sh — Overall Week 2 health dashboard.
# Shows at a glance: service states, timers, logs usage.
set -euo pipefail

echo "========================================"
echo " GreenDevCorp — Week 2 Status Dashboard"
echo " $(date)"
echo "========================================"
echo ""

# ── Services ──────────────────────────────────────────────────────────────────
echo "--- Services ---"
for svc in nginx p1-backup.service; do
    STATE=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
    printf "  %-28s active=%-10s enabled=%s\n" "$svc" "$STATE" "$ENABLED"
done

# ── Timers ────────────────────────────────────────────────────────────────────
echo ""
echo "--- Timers ---"
systemctl list-timers --no-pager | grep -E "p1-backup|NEXT" || true

# ── Journal disk usage ────────────────────────────────────────────────────────
echo ""
echo "--- Journal disk usage ---"
journalctl --disk-usage 2>/dev/null || true

# ── Recent errors ─────────────────────────────────────────────────────────────
echo ""
echo "--- Recent errors (all units, last 1h) ---"
journalctl -p err --since "1 hour ago" --no-pager -n 20 || true

# ── Backup files ──────────────────────────────────────────────────────────────
echo ""
echo "--- Backup files ---"
BACKUP_DIR="/var/backups/P1"
if [[ -d "$BACKUP_DIR" ]]; then
    COUNT=$(ls -1 "$BACKUP_DIR"/backup_* 2>/dev/null | wc -l)
    SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo "  $COUNT backups, total size: $SIZE"
    ls -lht "$BACKUP_DIR" | head -n 5
else
    echo "  No backup directory found."
fi

echo ""
echo "========================================"
