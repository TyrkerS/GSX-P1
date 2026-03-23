#!/bin/bash
# show-nginx-logs.sh — Visualitza els logs de Nginx
# Mostra: logs de journald, estat del servei, consell per a logs en temps real
set -euo pipefail

SINCE="${1:---since 'today'}"
LINES="${2:-50}"

echo "=== NGINX LOGS (last $LINES lines from today) ==="
echo ""
journalctl -u nginx --since "today" -n "$LINES" --no-pager

echo ""
echo "=== NGINX STATUS ==="
systemctl status nginx --no-pager -l || true

echo ""
echo "Tip: for real-time logs run: journalctl -u nginx -f"
