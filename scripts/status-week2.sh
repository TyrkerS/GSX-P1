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
