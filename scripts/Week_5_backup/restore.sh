#!/bin/bash
set -euo pipefail

PASSPHRASE_FILE="/etc/backup.passphrase"

BACKUP_FILE="${1:-}"
RESTORE_DIR="${2:-/tmp/restore_test}"

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Usage: $0 <backup_file> [restore_dir]"
    echo ""
    echo "Examples:"
    echo "  $0 /mnt/storage/backups/backup_2026-03-19_10-00-00.tar.gz.gpg"
    echo "  $0 /mnt/storage/backups/backup_2026-03-19_10-00-00.tar.gz /tmp/myrestore"
    exit 1
fi

[[ -f "$BACKUP_FILE" ]] || { echo "ERROR: Backup file not found: $BACKUP_FILE" >&2; exit 1; }


echo "=== RESTORE TEST ==="
echo "Source:      $BACKUP_FILE"
echo "Destination: $RESTORE_DIR"
echo ""

rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"

if [[ "$BACKUP_FILE" == *.gpg ]]; then
    echo "Detected encrypted backup — decrypting..."
    [[ -f "$PASSPHRASE_FILE" ]] \
        || { echo "ERROR: Passphrase file not found: $PASSPHRASE_FILE" >&2; exit 1; }

    gpg \
        --batch \
        --yes \
        --passphrase-file "$PASSPHRASE_FILE" \
        --decrypt "$BACKUP_FILE" \
    | tar \
        --preserve-permissions \
        --same-owner \
        -xzf - \
        -C "$RESTORE_DIR"
else
    echo "Detected plain backup — extracting..."
    tar \
        --preserve-permissions \
        --same-owner \
        -xzf "$BACKUP_FILE" \
        -C "$RESTORE_DIR"
fi

echo ""
echo "Restored files:"
ls -lh "$RESTORE_DIR"

FILE_COUNT=$(find "$RESTORE_DIR" -type f | wc -l)
echo ""
echo "Total files restored: $FILE_COUNT"

if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "ERROR: Restore appears empty!" >&2
    exit 1
fi

echo ""
echo "=== RESTORE OK: $FILE_COUNT files verified in $RESTORE_DIR ==="

