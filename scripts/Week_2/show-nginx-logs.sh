#!/bin/bash
set -euo pipefail

SINCE="${1:---since 'today'}"
LINES="${2:-50}"

echo "=== NGINX LOGS (last $LINES lines since today) ==="
echo ""
journalctl -u nginx --since "today" -n "$LINES" --no-pager

echo ""
echo "=== NGINX STATUS ==="
systemctl status nginx --no-pager -l || true

echo ""
echo "Tip: for live logs run: journalctl -u nginx -f"
