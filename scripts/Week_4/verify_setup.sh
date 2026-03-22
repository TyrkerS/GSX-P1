#!/bin/bash
set -euo pipefail

BASE="/home/greendevcorp"
GROUP="greendevcorp"
USERS=("dev1" "dev2" "dev3" "dev4")
PAM_LIMITS_FILE="/etc/security/limits.d/greendevcorp.conf"
PROFILE_FILE="/etc/profile.d/greendevcorp.sh"

ERRORS=0

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "[OK]    $desc"
    else
        echo "[ERROR] $desc"
        ERRORS=$((ERRORS + 1))
    fi
}

echo ""
echo "=== WEEK 4 VERIFICATION ==="
echo ""

# ── Users and group ───────────────────────────────────────────────────────────
echo "--- Users and group ---"
check "Group '$GROUP' exists"  getent group "$GROUP"
for USER in "${USERS[@]}"; do
    check "User '$USER' exists"                  id "$USER"
    check "User '$USER' in group '$GROUP'"       bash -c "id -nG $USER | grep -qw $GROUP"
    check "User '$USER' has home directory"      test -d "/home/$USER"
done

# ── Directory structure and permissions ───────────────────────────────────────
echo ""
echo "--- Directories and permissions ---"
check "Base dir exists"            test -d "$BASE"
check "bin/ exists"                test -d "$BASE/bin"
check "shared/ exists"             test -d "$BASE/shared"
check "done.log exists"            test -f "$BASE/done.log"

# Check setgid and sticky bit on shared/
check "shared/ has setgid bit"     bash -c 'stat -c %a '"$BASE/shared"' | grep -q "^[0-9]*[2-3][0-9][0-9][0-9]$\|^2770$\|^3770$"'
check "done.log owned by dev1"     bash -c '[[ $(stat -c %U '"$BASE/done.log"') == "dev1" ]]'

# ── ACLs ──────────────────────────────────────────────────────────────────────
echo ""
echo "--- POSIX ACLs ---"
check "setfacl command available"  command -v setfacl
check "getfacl command available"  command -v getfacl
check "done.log has ACL for dev1"  getfacl "$BASE/done.log" | grep -q "user:dev1:rw-"
check "shared/ has ACL for dev1"   getfacl "$BASE/shared"   | grep -q "user:dev1:rwx"
check "shared/ has default ACLs"   getfacl "$BASE/shared"   | grep -q "default:"

# Access control tests
echo ""
echo "--- Access control tests ---"
check "dev2 CANNOT write to done.log" \
    bash -c '! sudo -u dev2 bash -c "echo test >> '"$BASE/done.log"'" 2>/dev/null'
check "dev1 CAN write to done.log" \
    sudo -u dev1 bash -c "echo '[verify] test entry' >> $BASE/done.log"
check "dev3 CAN read done.log" \
    sudo -u dev3 bash -c "cat $BASE/done.log" >/dev/null
check "dev3 CANNOT write to shared/" \
    bash -c '! sudo -u dev3 bash -c "touch '"$BASE/shared/test_dev3_$$"'" 2>/dev/null'
check "dev1 CAN write to shared/" \
    sudo -u dev1 bash -c "touch $BASE/shared/test_dev1_$$ && rm $BASE/shared/test_dev1_$$"

# ── PAM resource limits ───────────────────────────────────────────────────────
echo ""
echo "--- PAM resource limits ---"
check "PAM limits file exists"    test -f "$PAM_LIMITS_FILE"
check "nproc limit configured"    grep -q "nproc"  "$PAM_LIMITS_FILE"
check "nofile limit configured"   grep -q "nofile" "$PAM_LIMITS_FILE"
check "memlock limit configured"  grep -q "memlock" "$PAM_LIMITS_FILE"

# Runtime verification: check limits are actually applied at login time
# -l flag = login shell → PAM reads limits.conf
echo ""
echo "--- PAM limits runtime check (login shell test) ---"
check "dev1 nofile soft limit <= 4096" \
    bash -c 'LIMIT=$(sudo -u dev1 bash -l -c "ulimit -Sn"); [[ "$LIMIT" -le 4096 ]]'
check "dev1 nproc soft limit <= 200" \
    bash -c 'LIMIT=$(sudo -u dev1 bash -l -c "ulimit -Su"); [[ "$LIMIT" -le 200 ]]'

# ── Environment ───────────────────────────────────────────────────────────────
echo ""
echo "--- Shell environment ---"
check "profile.d file exists"     test -f "$PROFILE_FILE"
check "PATH customization set"    grep -q "PATH" "$PROFILE_FILE"
check "Aliases configured"        grep -q "alias" "$PROFILE_FILE"

# ── Result ────────────────────────────────────────────────────────────────────
echo ""
if [[ "$ERRORS" -eq 0 ]]; then
    echo "=== VERIFICATION SUCCESSFUL ==="
    exit 0
else
    echo "=== VERIFICATION FAILED: $ERRORS error(s) ==="
    exit 1
fi
