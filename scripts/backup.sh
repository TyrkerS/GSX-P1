#!/bin/bash
# backup.sh — GreenDevCorp Week 1 backup script
# Packages admin files preserving permissions and encrypts with GPG.
# Used by the systemd backup service (p1-backup.service).
#
# Usage: sudo ./backup.sh [--no-encrypt]
#   --no-encrypt  Skip encryption (for testing only)
#
# Requires: /etc/backup.passphrase (chmod 600, owned root)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SRC="$PROJECT_ROOT"
DEST="$PROJECT_ROOT/backups"
PASSPHRASE_FILE="/etc/backup.passphrase"

ENCRYPT=true
if [[ "${1:-}" == "--no-encrypt" ]]; then
    ENCRYPT=false
    echo "WARNING: running without encryption (testing mode)" >&2
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# Pre-flight checks
[[ $EUID -eq 0 ]] || die "Must be run as root (needed for --same-owner)"
[[ -d "$SRC" ]]   || die "Source does not exist: $SRC"

if $ENCRYPT; then
    [[ -f "$PASSPHRASE_FILE" ]] || die "Passphrase file not found: $PASSPHRASE_FILE"
    [[ $(stat -c %a "$PASSPHRASE_FILE") == "600" ]] \
        || die "Passphrase file must be chmod 600"
fi

mkdir -p "$DEST"

TS="$(date +"%Y-%m-%d_%H-%M-%S")"
if $ENCRYPT; then
    OUT="$DEST/backup_${TS}.tar.gz.gpg"
else
    OUT="$DEST/backup_${TS}.tar.gz"
fi

log "Starting backup: $SRC → $OUT"

if $ENCRYPT; then
    tar \
      --preserve-permissions \
      --same-owner \
      --exclude="$PROJECT_ROOT/backups" \
      --exclude="$PROJECT_ROOT/logs" \
      --exclude="$PROJECT_ROOT/.git" \
      -czf - \
      -C "$PROJECT_ROOT" . \
    | gpg \
        --batch --yes \
        --symmetric \
        --cipher-algo AES256 \
        --passphrase-file "$PASSPHRASE_FILE" \
        -o "$OUT"
else
    tar \
      --preserve-permissions \
      --same-owner \
      --exclude="$PROJECT_ROOT/backups" \
      --exclude="$PROJECT_ROOT/logs" \
      --exclude="$PROJECT_ROOT/.git" \
      -czf "$OUT" \
      -C "$PROJECT_ROOT" .
fi

# Verify output
[[ -f "$OUT" ]] || die "Backup file was not created: $OUT"
[[ -s "$OUT" ]] || die "Backup file is empty: $OUT"

SIZE=$(du -sh "$OUT" | cut -f1)
log "Backup completed successfully: $OUT (size: $SIZE)"
