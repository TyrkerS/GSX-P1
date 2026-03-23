#!/bin/bash
# setup_passphrase.sh — Generació de contrasenya aleatòria per a encriptació de backups
# Crea /etc/backup.passphrase amb 32 caràcters, estableix permisos 600, mostra la contrasenya per copiar
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

PASSPHRASE=$(tr -dc 'A-Za-z0-9!@#%^&*_-' < /dev/urandom | head -c 32)

printf '%s' "$PASSPHRASE" > "$PASSPHRASE_FILE"
chmod 600 "$PASSPHRASE_FILE"
chown root:root "$PASSPHRASE_FILE"

echo "Passphrase file created: $PASSPHRASE_FILE"
echo ""
echo "=== IMPORTANT: Store this passphrase in a secure location! ==="
echo "    Without it, encrypted backups cannot be restored."
echo ""
echo "Passphrase: $PASSPHRASE"
echo ""
echo "Recommended: Copy this passphrase to a password manager or"
echo "to a secure offline location NOW, before closing this terminal."
