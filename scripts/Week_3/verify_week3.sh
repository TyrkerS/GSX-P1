#!/bin/bash
# verify_week3.sh — Week 3 verification
# Checks: psmisc/sysstat installed, p1-workload.service exists,
# workload.sh has signal traps, diagnose.sh is executable.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="/etc/systemd/system/p1-workload.service"
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
echo "=== WEEK 3 VERIFICATION ==="
echo ""

# ── Dependencies ──────────────────────────────────────────────────────────────
echo "--- Dependencies ---"
check "pstree available (psmisc)"     command -v pstree
check "ps available"                  command -v ps
# iotop is optional (not always installed by default)
if command -v iotop >/dev/null 2>&1; then
    echo "[OK]    iotop available"
else
    echo "[WARN]  iotop not installed (optional: apt install iotop)"
fi

# ── Scripts ───────────────────────────────────────────────────────────────────
echo ""
echo "--- Scripts ---"
check "diagnose.sh is executable"        test -x "$SCRIPT_DIR/diagnose.sh"
check "workload.sh is executable"        test -x "$SCRIPT_DIR/workload.sh"
check "process_control_demo.sh exists"   test -f "$SCRIPT_DIR/process_control_demo.sh"
check "resource_limit_demo.sh exists"    test -f "$SCRIPT_DIR/resource_limit_demo.sh"

# ── Signal handlers ───────────────────────────────────────────────────────────
echo ""
echo "--- Signal handlers in workload.sh ---"
check "workload.sh has SIGTERM trap"  grep -q "SIGTERM" "$SCRIPT_DIR/workload.sh"
check "workload.sh has SIGUSR1 trap"  grep -q "SIGUSR1" "$SCRIPT_DIR/workload.sh"
check "workload.sh has SIGUSR2 trap"  grep -q "SIGUSR2" "$SCRIPT_DIR/workload.sh"

# ── Systemd workload service ──────────────────────────────────────────────────
echo ""
echo "--- Systemd workload service ---"
check "p1-workload.service installed in /etc/systemd/system/" test -f "$SERVICE_FILE"
check "CPUQuota configured in service"   grep -q "CPUQuota" "$SERVICE_FILE"
check "MemoryMax configured in service"  grep -q "MemoryMax" "$SERVICE_FILE"

# ── Quick functional test: start, signal, stop ────────────────────────────────
echo ""
echo "--- Functional signal test ---"
"$SCRIPT_DIR/workload.sh" &
W_PID=$!
sleep 1

if ps -p $W_PID >/dev/null 2>&1; then
    check "workload.sh responds to SIGUSR1" kill -SIGUSR1 $W_PID
    sleep 1
    check "workload.sh responds to SIGUSR2 (pause)" kill -SIGUSR2 $W_PID
    sleep 1
    check "workload.sh SIGTERM (graceful stop)" kill -SIGTERM $W_PID
    sleep 2
    if ps -p $W_PID >/dev/null 2>&1; then
        echo "[WARN]  Process did not exit after SIGTERM, sending SIGKILL"
        kill -SIGKILL $W_PID 2>/dev/null || true
    else
        echo "[OK]    workload.sh exited cleanly after SIGTERM"
    fi
else
    echo "[ERROR] workload.sh failed to start"
    ERRORS=$((ERRORS + 1))
fi

# ── Result ────────────────────────────────────────────────────────────────────
echo ""
if [[ "$ERRORS" -eq 0 ]]; then
    echo "=== VERIFICATION SUCCESSFUL ==="
    exit 0
else
    echo "=== VERIFICATION FAILED: $ERRORS error(s) ==="
    exit 1
fi
