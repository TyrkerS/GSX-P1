#!/bin/bash
# setup_acl.sh — Configure POSIX ACLs for GreenDevCorp shared directories.
# Goes beyond standard Unix permissions to allow fine-grained access control.
#
# ACLs applied:
#   /home/greendevcorp/done.log  →  dev1 can write, all others read-only
#   /home/greendevcorp/shared    →  dev1+dev2 have full rwx, dev3+dev4 read-only
#   /home/greendevcorp/bin       →  all team members can execute (rx), cannot write
#
# Usage: sudo ./setup_acl.sh
set -euo pipefail

BASE="/home/greendevcorp"

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root." >&2; exit 1; }

# Verify ACL support (requires acl package and filesystem mount with acl option)
if ! command -v setfacl &>/dev/null; then
    echo "Installing acl package..."
    apt-get install -y acl
fi

echo "=== Configuring POSIX ACLs ==="
echo ""

# ── done.log: only dev1 can write; group can read ─────────────────────────────
echo "1) done.log — dev1: rw, everyone else in group: r--"
# Clear any existing ACLs first (idempotent)
setfacl -b "$BASE/done.log"
# Group members: read only
setfacl -m "g:greendevcorp:r--" "$BASE/done.log"
# dev1: read + write
setfacl -m "u:dev1:rw-" "$BASE/done.log"
echo "   ACL set on $BASE/done.log"

# ── shared: dev1+dev2 full access, dev3+dev4 read-only ───────────────────────
echo ""
echo "2) shared/ — dev1+dev2: rwx, dev3+dev4: r-x"
setfacl -b "$BASE/shared"
# CRITICAL: set base (owning) group to r-x first.
# Without this, group::rwx (from chmod 3770) wins over g:greendevcorp:r-x
# because ACL picks the MOST PERMISSIVE matching group entry.
setfacl -m "g::r-x"             "$BASE/shared"
setfacl -d -m "g::r-x"          "$BASE/shared"   # default: owning group r-x
# Now the named-group and user ACLs
setfacl -d -m "g:greendevcorp:r-x" "$BASE/shared"   # default: group read+exec
setfacl -d -m "u:dev1:rwx"         "$BASE/shared"   # default: dev1 full
setfacl -d -m "u:dev2:rwx"         "$BASE/shared"   # default: dev2 full
setfacl -m "g:greendevcorp:r-x"    "$BASE/shared"
setfacl -m "u:dev1:rwx"            "$BASE/shared"
setfacl -m "u:dev2:rwx"            "$BASE/shared"
echo "   ACL set on $BASE/shared (including defaults for new files)"

# ── bin: all team members can read and execute, none can write ────────────────
echo ""
echo "3) bin/ — all group members: r-x (no write)"
setfacl -b "$BASE/bin"
setfacl -m "g:greendevcorp:r-x" "$BASE/bin"
echo "   ACL set on $BASE/bin"

# ── Verification ──────────────────────────────────────────────────────────────
echo ""
echo "=== ACL Verification ==="
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
echo "=== ACL setup complete ==="
echo ""
echo "Test access control with:"
echo "  sudo -u dev2 bash -c 'echo test >> $BASE/done.log'  # should FAIL"
echo "  sudo -u dev1 bash -c 'echo test >> $BASE/done.log'  # should SUCCEED"
echo "  sudo -u dev3 bash -c 'ls $BASE/shared'              # should SUCCEED (r-x)"
echo "  sudo -u dev3 bash -c 'touch $BASE/shared/file'      # should FAIL (no write)"
