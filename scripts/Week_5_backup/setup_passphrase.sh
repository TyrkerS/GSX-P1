#!/bin/bash
# setup_passphrase.sh — Create the GPG passphrase file for encrypted backups.
# Generates a random 32-character passphrase and stores it in
# /etc/backup.passphrase with strict permissions (root:root, 600).
#
# Run once during initial storage setup. Keep the passphrase safe —
# without it, encrypted backups CANNOT be restored.
#
# Usage: sudo ./setup_passphrase.sh

set -euo pipefail

PASSPHRASE_FILE="/etc/backup.passphrase"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Must be run as root." >&2
    exit 1
fi

if [[ -f "$PASSPHRASE_FILE" ]]; then
    echo "Passphrase file already exists: $PASSPHRASE_FILE"
    echo "Delete it manually if you want to regenerate it."
    exit 0
fi

# Generate a 32-character random passphrase (alphanumeric + symbols)
PASSPHRASE=$(tr -dc 'A-Za-z0-9!@#%^&*_-' < /dev/urandom | head -c 32 || true)
[[ -z "$PASSPHRASE" ]] && PASSPHRASE=$(openssl rand -base64 24)

printf '%s' "$PASSPHRASE" > "$PASSPHRASE_FILE"
chmod 600 "$PASSPHRASE_FILE"
chown root:root "$PASSPHRASE_FILE"

echo "Passphrase file created: $PASSPHRASE_FILE"
echo ""
echo "=== IMPORTANT: Store this passphrase somewhere safe! ==="
echo "    Without it, encrypted backups cannot be restored."
echo ""
echo "Passphrase: $PASSPHRASE"
echo ""
echo "Recommended: copy this passphrase to a password manager or"
echo "secure offline location NOW, before closing this terminal."
