#!/bin/bash
# verify_week2.sh — Week 2 comprehensive verification
# Checks: Nginx, backup service, backup timer, backup files, journald config.
set -euo pipefail

ERRORS=0
BACKUP_TIMER="p1-backup.timer"
BACKUP_SERVICE="p1-backup.service"
NGINX_OVERRIDE="/etc/systemd/system/nginx.service.d/override.conf"
JOURNAL_CONF="/etc/systemd/journald.conf.d/limits.conf"

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "[OK]    $desc"
    else
        echo "[ERROR] $desc"
        ERRORS=$((ERRORS + 1))
    fi
}

echo ""
echo "=== WEEK 2 VERIFICATION ==="
echo ""

# ── Nginx ─────────────────────────────────────────────────────────────────────
echo "--- Nginx ---"
check "Nginx installed"               command -v nginx
check "Nginx enabled at boot"         systemctl is-enabled nginx
check "Nginx active (running)"        systemctl is-active nginx
check "Nginx restart policy set"      grep -q "Restart=on-failure" "$NGINX_OVERRIDE"

# ── Backup service ────────────────────────────────────────────────────────────
echo ""
echo "--- Backup service ---"
check "Backup service unit exists"    test -f "/etc/systemd/system/$BACKUP_SERVICE"
check "Backup timer unit exists"      test -f "/etc/systemd/system/$BACKUP_TIMER"
check "Backup timer enabled"          systemctl is-enabled "$BACKUP_TIMER"
check "Backup timer active"           systemctl is-active  "$BACKUP_TIMER"

# Verify the timer has a next elapse time (it's actually scheduled)
NEXT=$(systemctl show "$BACKUP_TIMER" -p NextElapseUSecRealtime 2>/dev/null | cut -d= -f2 || true)
check "Backup timer is scheduled"     test -n "$NEXT"

# ── Backup files ──────────────────────────────────────────────────────────────
echo ""
echo "--- Backup files ---"
BACKUP_DIR="/var/backups/P1"
LATEST=$(ls -1t "$BACKUP_DIR"/backup_*.tar.gz* 2>/dev/null | head -n 1 || true)
check "At least one backup file exists" test -n "${LATEST:-}"
if [[ -n "${LATEST:-}" ]]; then
    check "Latest backup is non-empty"  test -s "$LATEST"
    echo "       Latest: $LATEST"
fi

# ── Journald / log management ─────────────────────────────────────────────────
echo ""
echo "--- Log management ---"
check "journald limits config exists" test -f "$JOURNAL_CONF"
check "journald SystemMaxUse set"     grep -q "SystemMaxUse" "$JOURNAL_CONF"
check "journald MaxRetentionSec set"  grep -q "MaxRetentionSec" "$JOURNAL_CONF"

# ── Result ────────────────────────────────────────────────────────────────────
echo ""
if [[ "$ERRORS" -eq 0 ]]; then
    echo "=== VERIFICATION SUCCESSFUL ==="
    exit 0
else
    echo "=== VERIFICATION FAILED: $ERRORS error(s) ==="
    exit 1
fi

