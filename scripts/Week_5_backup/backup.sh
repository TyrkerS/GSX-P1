#!/bin/bash
# backup.sh — Script de backup complet a  emmagatzematge remot
# Crea fitxers tar.gz.gpg encriptats amb contrasenya, implementa rotació de backups (7 diaris, 4 setmanals), comprova muntatge, registra logs
set -euo pipefail

#  Configuració
SOURCE="/home"                          
DEST="/mnt/storage/backups"            
PASSPHRASE_FILE="/etc/backup.passphrase" 
KEEP_DAILY=7                            
KEEP_WEEKLY=4                           


ENCRYPT=true
if [[ "${1:-}" == "--no-encrypt" ]]; then
    ENCRYPT=false
    echo "WARNING: execution without encryption (test mode)" >&2
fi

#  Funcions auxiliars
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

#  Pre-flight checks
[[ $EUID -eq 0 ]] || die "Must be run as root (needed for --same-owner)"
[[ -d "$SOURCE" ]]  || die "Source directory does not exist: $SOURCE"
mountpoint -q /mnt/storage || die "/mnt/storage is not mounted"

if $ENCRYPT; then
    [[ -f "$PASSPHRASE_FILE" ]] || die "Passphrase file not found: $PASSPHRASE_FILE"
    [[ $(stat -c %a "$PASSPHRASE_FILE") == "600" ]] \
        || die "Passphrase file must be chmod 600: $PASSPHRASE_FILE"
fi

mkdir -p "$DEST"

#  Backup
DATE=$(date +%F_%H-%M-%S)
WEEKDAY=$(date +%u)  # 7 = Sunday

if $ENCRYPT; then
    EXT="tar.gz.gpg"
    BACKUP_FILE="$DEST/backup_${DATE}.${EXT}"
else
    EXT="tar.gz"
    BACKUP_FILE="$DEST/backup_${DATE}.${EXT}"
fi

log "Starting backup: $SOURCE → $BACKUP_FILE"

if $ENCRYPT; then
    tar \
        --preserve-permissions \
        --same-owner \
        --exclude="$DEST" \
        -czf - \
        "$SOURCE" \
    | gpg \
        --batch \
        --yes \
        --symmetric \
        --cipher-algo AES256 \
        --passphrase-file "$PASSPHRASE_FILE" \
        -o "$BACKUP_FILE"
else
    tar \
        --preserve-permissions \
        --same-owner \
        --exclude="$DEST" \
        -czf "$BACKUP_FILE" \
        "$SOURCE"
fi


[[ -f "$BACKUP_FILE" ]] || die "Backup file was not created: $BACKUP_FILE"
[[ -s "$BACKUP_FILE" ]] || die "Backup file is empty: $BACKUP_FILE"

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup completed successfully: $BACKUP_FILE (size: $SIZE)"


log "Rotating daily backups (keeping $KEEP_DAILY)..."
ls -1t "$DEST"/backup_*.${EXT} 2>/dev/null \
    | tail -n +"$((KEEP_DAILY + 1))" \
    | xargs --no-run-if-empty rm -v --

# Create weekly copy on Sunday
if [[ "$WEEKDAY" -eq 7 ]]; then
    WEEKLY_DIR="$DEST/weekly"
    mkdir -p "$WEEKLY_DIR"
    cp "$BACKUP_FILE" "$WEEKLY_DIR/"
    log "Weekly backup stored: $WEEKLY_DIR/$(basename "$BACKUP_FILE")"

    log "Rotating weekly backups (keeping $KEEP_WEEKLY)..."
    ls -1t "$WEEKLY_DIR"/backup_*.${EXT} 2>/dev/null \
        | tail -n "$((KEEP_WEEKLY + 1))" \
        | xargs --no-run-if-empty rm -v --
fi

log "Done."

