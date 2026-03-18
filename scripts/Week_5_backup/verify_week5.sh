#!/bin/bash
set -euo pipefail

MOUNT_POINT="/mnt/storage"
BACKUP_DIR="/mnt/storage/backups"
LOG_FILE="/var/log/backup.log"
RESTORE_DIR="/tmp/restore_verify"

ERRORS=0

check() {
    DESCRIPTION="$1"
    shift

    if "$@"; then
        echo "[OK] $DESCRIPTION"
    else
        echo "[ERROR] $DESCRIPTION"
        ERRORS=$((ERRORS+1))
    fi
}

echo
echo "=== WEEK 5 VERIFICATION ==="
echo

# 1. Check mount point exists
check "Mount point exists" test -d "$MOUNT_POINT"

# 2. Check disk is mounted
check "Storage mounted on $MOUNT_POINT" findmnt -rn "$MOUNT_POINT"

# 3. Check fstab entry exists
check "fstab contains storage entry" grep -q "$MOUNT_POINT" /etc/fstab

# 4. Check backup directory exists
check "Backup directory exists" test -d "$BACKUP_DIR"

# 5. Check at least one backup file exists
LATEST_BACKUP=$(ls -1t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -n 1 || true)
check "At least one backup file exists" test -n "${LATEST_BACKUP:-}"

# 6. Check log file exists
check "Backup log exists" test -f "$LOG_FILE"

# 7. Check log contains successful backup message
check "Backup log contains completion message" grep -q "Backup completed" "$LOG_FILE"

# 8. Test restore
if [[ -n "${LATEST_BACKUP:-}" ]]; then
    echo
    echo "Testing restore using: $LATEST_BACKUP"

    rm -rf "$RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"

    if tar -xzf "$LATEST_BACKUP" -C "$RESTORE_DIR"; then
        echo "[OK] Restore extraction succeeded"
    else
        echo "[ERROR] Restore extraction failed"
        ERRORS=$((ERRORS+1))
    fi

    check "Restored content exists" test -d "$RESTORE_DIR/home"
fi

echo
if [[ "$ERRORS" -eq 0 ]]; then
    echo "=== VERIFICATION SUCCESSFUL ==="
    exit 0
else
    echo "=== VERIFICATION FAILED: $ERRORS error(s) detected ==="
    exit 1
fi
