#!/bin/bash
# backup.sh — GreenDevCorp automated backup script
# Backs up SOURCE to DEST with encryption, permission preservation,
# and retention rotation (7 daily, 4 weekly copies).
#
# Usage: ./backup.sh [--no-encrypt]
#   --no-encrypt   Skip GPG encryption (for testing only)
#
# Requires: GPG passphrase in /etc/backup.passphrase (chmod 600, owned root)
# Run as root or via sudo (needed for --same-owner and /etc/backup.passphrase)

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SOURCE="/home"                          # What to back up
DEST="/mnt/storage/backups"            # Where to store backups
PASSPHRASE_FILE="/etc/backup.passphrase" # GPG symmetric passphrase
KEEP_DAILY=7                            # Daily copies to keep
KEEP_WEEKLY=4                           # Weekly copies to keep (on Sundays)
# ──────────────────────────────────────────────────────────────────────────────

ENCRYPT=true
if [[ "${1:-}" == "--no-encrypt" ]]; then
    ENCRYPT=false
    echo "WARNING: running without encryption (testing mode)" >&2
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Must be run as root (needed for --same-owner)"
[[ -d "$SOURCE" ]]  || die "Source directory does not exist: $SOURCE"

# Use /mnt/storage if mounted, fall back to /var/backups/P1 otherwise
if ! mountpoint -q /mnt/storage 2>/dev/null; then
    log "WARNING: /mnt/storage not mounted — using fallback: /var/backups/P1"
    DEST="/var/backups/P1"
fi
mkdir -p "$DEST"

if $ENCRYPT; then
    [[ -f "$PASSPHRASE_FILE" ]] || die "Passphrase file not found: $PASSPHRASE_FILE"
    [[ $(stat -c %a "$PASSPHRASE_FILE") == "600" ]] \
        || die "Passphrase file must be chmod 600: $PASSPHRASE_FILE"
fi

mkdir -p "$DEST"

# ── Backup ────────────────────────────────────────────────────────────────────
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

# Create tar and optionally pipe through GPG symmetric encryption
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

# Verify the output file was actually created and has size > 0
[[ -f "$BACKUP_FILE" ]] || die "Backup file was not created: $BACKUP_FILE"
[[ -s "$BACKUP_FILE" ]] || die "Backup file is empty: $BACKUP_FILE"

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup completed successfully: $BACKUP_FILE (size: $SIZE)"

# ── Retention / rotation ──────────────────────────────────────────────────────
# Keep only the last KEEP_DAILY daily backups
log "Rotating daily backups (keeping $KEEP_DAILY)..."
ls -1t "$DEST"/backup_*.${EXT} 2>/dev/null \
    | tail -n +"$((KEEP_DAILY + 1))" \
    | xargs --no-run-if-empty rm -v --

# Weekly retention: on Sundays, copy latest backup to weekly slot
if [[ "$WEEKDAY" -eq 7 ]]; then
    WEEKLY_DIR="$DEST/weekly"
    mkdir -p "$WEEKLY_DIR"
    cp "$BACKUP_FILE" "$WEEKLY_DIR/"
    log "Weekly copy stored: $WEEKLY_DIR/$(basename "$BACKUP_FILE")"

    log "Rotating weekly backups (keeping $KEEP_WEEKLY)..."
    ls -1t "$WEEKLY_DIR"/backup_*.${EXT} 2>/dev/null \
        | tail -n +"$((KEEP_WEEKLY + 1))" \
        | xargs --no-run-if-empty rm -v --
fi

log "Done."

