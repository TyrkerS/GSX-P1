#!/bin/bash
set -euo pipefail

MOUNT_POINT="/mnt/storage"
BACKUP_DIR="$MOUNT_POINT/backups"
PASSPHRASE_FILE="/etc/backup.passphrase"
RESTORE_DIR="/tmp/restore_verify_$$"
TIMER_NAME="p1-backup.timer"

ERRORS=0

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
echo "=== WEEK 5 VERIFICATION ==="
echo ""


echo "--- Storage ---"
check "Mount point exists"              test -d "$MOUNT_POINT"
check "Storage mounted on $MOUNT_POINT" mountpoint -q "$MOUNT_POINT"
check "fstab entry uses UUID"           grep -P "^UUID=\S+\s+$MOUNT_POINT" /etc/fstab
check "Backup directory exists"         test -d "$BACKUP_DIR"


echo ""
echo "--- Encryption ---"
check "GPG is installed"                command -v gpg
check "Passphrase file exists"          test -f "$PASSPHRASE_FILE"
check "Passphrase file is chmod 600"    bash -c '[[ $(stat -c %a '"$PASSPHRASE_FILE"') == "600" ]]'
check "Passphrase file owned by root"   bash -c '[[ $(stat -c %U '"$PASSPHRASE_FILE"') == "root" ]]'


echo ""
echo "--- Backup files ---"
LATEST=$(ls -1t "$BACKUP_DIR"/backup_*.tar.gz.gpg "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -n 1 || true)
check "At least one backup file exists" test -n "${LATEST:-}"
check "Latest backup file is non-empty" test -s "${LATEST:-/dev/null}"

if [[ -n "${LATEST:-}" ]]; then
    echo "       Latest: $LATEST ($(du -sh "$LATEST" | cut -f1))"
fi


DAILY_COUNT=$(ls -1 "$BACKUP_DIR"/backup_*.tar.gz* 2>/dev/null | wc -l || echo 0)
echo "       Daily backups present: $DAILY_COUNT"


echo ""
echo "--- Systemd timer ---"
check "Timer unit is enabled"           systemctl is-enabled "$TIMER_NAME"
check "Timer unit is active"            systemctl is-active  "$TIMER_NAME"

NEXT=$(systemctl show "$TIMER_NAME" -p NextElapseUSecRealtime 2>/dev/null | cut -d= -f2 || true)
[[ -n "$NEXT" ]] && echo "       Next run: $(systemd-analyze calendar daily 2>/dev/null | grep 'Next elapse' || echo 'see: systemctl list-timers')"

echo ""
echo "--- Restore test ---"

if [[ -n "${LATEST:-}" ]]; then
    mkdir -p "$RESTORE_DIR"

    if [[ "$LATEST" == *.gpg ]]; then
        gpg \
            --batch --yes \
            --passphrase-file "$PASSPHRASE_FILE" \
            --decrypt "$LATEST" \
        | tar --preserve-permissions --same-owner -xzf - -C "$RESTORE_DIR" \
            && echo "[OK]    Encrypted restore extraction succeeded" \
            || { echo "[ERROR] Encrypted restore extraction failed"; ERRORS=$((ERRORS + 1)); }
    else
        tar --preserve-permissions --same-owner -xzf "$LATEST" -C "$RESTORE_DIR" \
            && echo "[OK]    Plain restore extraction succeeded" \
            || { echo "[ERROR] Plain restore extraction failed"; ERRORS=$((ERRORS + 1)); }
    fi

    FILE_COUNT=$(find "$RESTORE_DIR" -type f | wc -l)
    check "Restored content is non-empty (files found: $FILE_COUNT)" test "$FILE_COUNT" -gt 0

    rm -rf "$RESTORE_DIR"
else
    echo "[SKIP]  No backup file found — skipping restore test"
fi

echo ""
if [[ "$ERRORS" -eq 0 ]]; then
    echo "=== VERIFICATION SUCCESSFUL ==="
    exit 0
else
    echo "=== VERIFICATION FAILED: $ERRORS error(s) ==="
    exit 1
fi

