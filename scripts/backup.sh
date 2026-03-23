#!/bin/bash
# backup.sh — Script de backup simple del projecte
# Crea fitxer tar.gz comprimit amb timestamp, exclou directoris de backups/logs/.git, valida creació
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SRC="$PROJECT_ROOT"
DEST="$PROJECT_ROOT/backups"
TS="$(date +"%Y-%m-%d_%H-%M-%S")"
OUT="$DEST/backup_${TS}.tar.gz"

echo "==> Starting backup..."
echo "Source: $SRC"
echo "Destination: $OUT"

mkdir -p "$DEST"

# Create backup excluding unnecessary directories and preserving permissions
tar \
  --exclude="$PROJECT_ROOT/backups" \
  --exclude="$PROJECT_ROOT/logs" \
  --exclude="$PROJECT_ROOT/.git" \
  --preserve-permissions \
  --same-owner \
  -czf "$OUT" \
  -C "$PROJECT_ROOT" .

# Validate that the backup was created correctly
if [[ -f "$OUT" ]]; then
    echo "Backup created successfully: $OUT"
else
    echo "Backup failed!"
    exit 1
fi

echo "==> Backup completed."