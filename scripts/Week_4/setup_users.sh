#!/bin/bash
# setup_users.sh — Create GreenDevCorp developer users and group.
# Generates a random password per user; prints credentials once.
# Idempotent: skips existing users.
#
# Usage: sudo ./setup_users.sh
set -euo pipefail

GROUP="greendevcorp"
USERS=("dev1" "dev2" "dev3" "dev4")

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root." >&2; exit 1; }

echo "Creating group '$GROUP'..."
groupadd -f "$GROUP"

echo ""
echo "Creating users..."
echo "============================================"

for USER in "${USERS[@]}"; do
    if id "$USER" &>/dev/null; then
        echo "[$USER] Already exists — skipping."
    else
        # Generate a random 16-char password
        # '|| true' prevents SIGPIPE error (head closes pipe before tr finishes)
        PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16 || true)
        [[ -z "$PASS" ]] && PASS="ChangeMe$(date +%s)"

        useradd \
            --create-home \
            --gid "$GROUP" \
            --shell /bin/bash \
            "$USER"

        echo "$USER:$PASS" | chpasswd

        # Force password change on first login (least privilege)
        chage -d 0 "$USER"

        echo "[$USER] Created  password: $PASS  (change on first login)"
    fi
done

echo "============================================"
echo ""
echo "Users created. Store passwords in a password manager."
echo "Users will be forced to change password on first login."
