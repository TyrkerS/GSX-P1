#!/bin/bash
# setup_all.sh — Full system setup orchestrator.
# Runs all weekly setup scripts in the correct dependency order.
#
# Usage: sudo ./scripts/setup_all.sh [OPTIONS]
#   --ssh-pubkey "ssh-ed25519 ..."   Public key to install for the gsx user (W1)
#   --start-week N                   Skip weeks before N (resume partial setup)
#   --disk /dev/sdb                  Disk to use for Week 5 storage (default: /dev/sdb)
#   --no-nfs                         Skip NFS setup (default: NFS is skipped)
#
# Example (first time):
#   sudo ./scripts/setup_all.sh --ssh-pubkey "$(cat ~/.ssh/id_ed25519.pub)"
#
# Example (resume from Week 4):
#   sudo ./scripts/setup_all.sh --start-week 4
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
SSH_PUBKEY=""
START_WEEK=1
DISK="/dev/sdb"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ssh-pubkey)   SSH_PUBKEY="$2"; shift 2 ;;
        --start-week)   START_WEEK="$2"; shift 2 ;;
        --disk)         DISK="$2"; shift 2 ;;
        --no-nfs)       shift ;;
        -h|--help)
            sed -n '/^# Usage/,/^set -/p' "$0" | head -n -1 | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root." >&2; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────────
WEEK=0
ERRORS=0

section() {
    WEEK=$1
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  WEEK $WEEK: $2"
    echo "════════════════════════════════════════════════════"
}

run() {
    local script="$1"; shift
    echo "  → $script $*"
    if bash "$script" "$@"; then
        echo "  ✔  Done"
    else
        echo "  ✖  FAILED: $script" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

skip() {
    [[ $WEEK -ge $START_WEEK ]]
}

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       GreenDevCorp — Full System Setup               ║"
echo "║       Starting from Week $START_WEEK                            ║"
echo "╚══════════════════════════════════════════════════════╝"

# ── Week 1: Foundation ────────────────────────────────────────────────────────
section 1 "Foundation & Remote Access"
if [[ $START_WEEK -le 1 ]]; then
    if [[ -n "$SSH_PUBKEY" ]]; then
        run "$SCRIPT_DIR/Week_1/setup_server.sh" --ssh-pubkey "$SSH_PUBKEY"
    else
        run "$SCRIPT_DIR/Week_1/setup_server.sh"
        echo "  ⚠  No --ssh-pubkey provided. Password auth is still enabled."
        echo "     Re-run with --ssh-pubkey to fully harden SSH."
    fi
fi

# ── Week 2: Services ─────────────────────────────────────────────────────────
section 2 "Services, Observability & Automation"
if [[ $START_WEEK -le 2 ]]; then
    run "$SCRIPT_DIR/Week_2/week2_setup.sh"
    # Trigger one unencrypted backup to verify the system works.
    # --no-encrypt is used because /etc/backup.passphrase (Week 5) doesn't exist yet.
    # The nightly systemd timer will run encrypted backups once Week 5 is complete.
    echo "  → Running initial smoke-test backup (no encryption)..."
    bash "$SCRIPT_DIR/Week_5_backup/backup.sh" --no-encrypt \
        && echo "  ✔  Initial backup created in /var/backups/P1/" \
        || echo "  ⚠  Backup smoke-test failed — check backup.sh manually"
fi

# ── Week 3: Process management ───────────────────────────────────────────────
section 3 "Process Management & Resource Control"
if [[ $START_WEEK -le 3 ]]; then
    run "$SCRIPT_DIR/Week_3/setup_week3.sh"
fi

# ── Week 4: Users & access control ───────────────────────────────────────────
section 4 "Users, Groups & Access Control"
if [[ $START_WEEK -le 4 ]]; then
    run "$SCRIPT_DIR/Week_4/setup_users.sh"
    run "$SCRIPT_DIR/Week_4/setup_directories.sh"
    run "$SCRIPT_DIR/Week_4/setup_acl.sh"
    run "$SCRIPT_DIR/Week_4/setup_pam_limits.sh"
    run "$SCRIPT_DIR/Week_4/setup_environment.sh"
fi

# ── Week 5: Storage & backup ──────────────────────────────────────────────────
section 5 "Storage, Backup & Recovery"
if [[ $START_WEEK -le 5 ]]; then
    if [[ -b "$DISK" ]]; then
        run "$SCRIPT_DIR/Week_5_backup/setup_storage.sh" "$DISK"
        run "$SCRIPT_DIR/Week_5_backup/setup_passphrase.sh"
        echo "  → Triggering initial backup run to storage..."
        systemctl start p1-backup.service && echo "  ✔  Backup triggered" \
            || echo "  ⚠  Backup trigger failed"
    else
        echo "  ⚠  Disk $DISK not found — skipping Week 5 storage setup."
        echo "     Add a second disk in VirtualBox and re-run with: --start-week 5 --disk /dev/sdb"
        echo "  → Configuring passphrase only (no disk)..."
        run "$SCRIPT_DIR/Week_5_backup/setup_passphrase.sh"
    fi
fi

# ── Reload systemd ────────────────────────────────────────────────────────────
echo ""
echo "  → Reloading systemd daemon..."
systemctl daemon-reload && echo "  ✔  Done" || echo "  ⚠  daemon-reload failed"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
if [[ $ERRORS -eq 0 ]]; then
    echo "  ✔  SETUP COMPLETE — all weeks configured"
    echo ""
    echo "  Next step: run sudo ./scripts/verify_all.sh"
else
    echo "  ✖  SETUP FINISHED WITH $ERRORS ERROR(S)"
    echo "     Review the output above and fix the failing weeks."
    echo "     You can resume with: --start-week <N>"
fi
echo "════════════════════════════════════════════════════"
exit $ERRORS
