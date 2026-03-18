#!/bin/bash
set -euo pipefail

SOURCE="/home/gsx"
DEST="/mnt/storage/backups"
DATE=$(date +%F_%H-%M-%S)
BACKUP_FILE="$DEST/backup_$DATE.tar.gz"
LOG_FILE="/var/log/backup.log"

mkdir -p "$DEST"

echo "[$(date)] Starting backup..." >> $LOG_FILE

tar -czf "$BACKUP_FILE" "$SOURCE"

echo "[$(date)] Backup completed: $BACKUP_FILE" >> $LOG_FILE
