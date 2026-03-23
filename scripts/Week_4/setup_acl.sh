#!/bin/bash
# setup_acl.sh — Configuració de ACLs POSIX per a directoris compartits de GreenDevCorp
# Va més allà dels permisos Unix estàndard per permetre control d'accés granular
#
# ACLs aplicades:
#   /home/greendevcorp/done.log  →  dev1 pot escriure, altres només lectura
#   /home/greendevcorp/shared    →  dev1+dev2 rwx complet, dev3+dev4 només lectura
#   /home/greendevcorp/bin       →  tots els membres de l'equip rx (execució), ningú pot escriure
#
# Ús: sudo ./setup_acl.sh
set -euo pipefail

BASE="/home/greendevcorp"

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root." >&2; exit 1; }

# Verify ACL support (requires acl package and filesystem mounted with acl option)
if ! command -v setfacl &>/dev/null; then
    echo "Installing acl package..."
    apt-get install -y acl
fi

echo "=== Configuring POSIX ACLs ==="
echo ""

# ── done.log: only dev1 can write; group can read ─────────────────────────────
echo "1) done.log — dev1: rw, other group members: r--"
# Clear existing ACLs first (idempotent)
setfacl -b "$BASE/done.log"
# Group members: read-only
setfacl -m "g:greendevcorp:r--" "$BASE/done.log"
# dev1: read + write
setfacl -m "u:dev1:rw-" "$BASE/done.log"
echo "   ACL set on $BASE/done.log"

# ── shared: dev1+dev2 full access, dev3+dev4 read-only ──────────────────
echo ""
echo "2) shared/ — dev1+dev2: rwx, dev3+dev4: r-x"
setfacl -b "$BASE/shared"
# Default ACLs ensure new files inside inherit the same rules
setfacl -d -m "g:greendevcorp:r-x" "$BASE/shared"   # default: group read+execute
setfacl -d -m "u:dev1:rwx"         "$BASE/shared"   # default: dev1 full
setfacl -d -m "u:dev2:rwx"         "$BASE/shared"   # default: dev2 full
# Apply same to directory itself
setfacl -m "g:greendevcorp:r-x"    "$BASE/shared"
setfacl -m "u:dev1:rwx"            "$BASE/shared"
setfacl -m "u:dev2:rwx"            "$BASE/shared"
echo "   ACL set on $BASE/shared (including default values for new files)"

# ── bin: all group members can read and execute, nobody can write ──────────────────
echo ""
echo "3) bin/ — all group members: r-x (no write)"
setfacl -b "$BASE/bin"
setfacl -m "g:greendevcorp:r-x" "$BASE/bin"
echo "   ACL set on $BASE/bin"

# ── Verification ────────────────────────────────────────────────────────────
echo ""
echo "=== ACL Configuration Verification ==="
echo ""
echo "--- done.log ---"
getfacl "$BASE/done.log"

echo ""
echo "--- shared/ ---"
getfacl "$BASE/shared"

echo ""
echo "--- bin/ ---"
getfacl "$BASE/bin"

echo ""
echo "=== ACL Configuration Completed ==="
echo ""
echo "Test access control with:"
echo "  sudo -u dev2 bash -c 'echo test >> $BASE/done.log'  # should FAIL"
echo "  sudo -u dev1 bash -c 'echo test >> $BASE/done.log'  # should WORK"
echo "  sudo -u dev3 bash -c 'ls $BASE/shared'              # should WORK (r-x)"
echo "  sudo -u dev3 bash -c 'touch $BASE/shared/file'      # should FAIL (no write)"
