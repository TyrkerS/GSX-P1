#!/bin/bash
set -euo pipefail

BACKUP_FILE="$1"
RESTORE_DIR="/tmp/restore_test"

if [[ -z "${BACKUP_FILE:-}" ]]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

echo "=== RESTORE TEST ==="

echo "Creating restore directory..."
rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"

echo "Restoring backup..."
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

echo "Restore completed in: $RESTORE_DIR"

echo "Listing restored files:"
ls -l "$RESTORE_DIR"

echo "=== RESTORE OK ==="
