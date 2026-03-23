#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ── Argument parsing ──────────────────────────────────────────────────────────
START_WEEK=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --start-week) START_WEEK="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── State tracking ────────────────────────────────────────────────────────────
FAILED_WEEKS=()
PASSED_WEEKS=()
SKIPPED_WEEKS=()

# ── Helpers ───────────────────────────────────────────────────────────────────
run_verify() {
    local week="$1"
    local label="$2"
    local script="$3"

    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  WEEK $week: $label"
    echo "════════════════════════════════════════════════════"

    if [[ $week -lt $START_WEEK ]]; then
        echo "  [SKIP] Week $week skipped (--start-week $START_WEEK)"
        SKIPPED_WEEKS+=("Week $week")
        return
    fi

    if [[ ! -f "$script" ]]; then
        echo "  [SKIP] $script not found"
        SKIPPED_WEEKS+=("Week $week")
        return
    fi

    if bash "$script"; then
        PASSED_WEEKS+=("Week $week — $label")
    else
        FAILED_WEEKS+=("Week $week — $label")
    fi
}

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║    GreenDevCorp — Full System Verification           ║"
echo "╚══════════════════════════════════════════════════════╝"

# ── Run all weekly verifications ─────────────────────────────────────────────
run_verify 1 "Foundation & Remote Access" \
    "$SCRIPT_DIR/Week_1/verify_setup.sh"

run_verify 2 "Services, Observability & Automation" \
    "$SCRIPT_DIR/Week_2/verify_week2.sh"

run_verify 3 "Process Management & Resource Control" \
    "$SCRIPT_DIR/Week_3/verify_week3.sh"

run_verify 4 "Users, Groups & Access Control" \
    "$SCRIPT_DIR/Week_4/verify_setup.sh"

run_verify 5 "Storage, Backup & Recovery" \
    "$SCRIPT_DIR/Week_5_backup/verify_week5.sh"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
echo "  VERIFICATION SUMMARY"
echo "════════════════════════════════════════════════════"

if [[ ${#PASSED_WEEKS[@]} -gt 0 ]]; then
    echo ""
    echo "  PASSED (${#PASSED_WEEKS[@]}):"
    for w in "${PASSED_WEEKS[@]}"; do
        echo "    ✔  $w"
    done
fi

if [[ ${#SKIPPED_WEEKS[@]} -gt 0 ]]; then
    echo ""
    echo "  SKIPPED (${#SKIPPED_WEEKS[@]}):"
    for w in "${SKIPPED_WEEKS[@]}"; do
        echo "    ⊘  $w"
    done
fi

if [[ ${#FAILED_WEEKS[@]} -gt 0 ]]; then
    echo ""
    echo "  FAILED (${#FAILED_WEEKS[@]}):"
    for w in "${FAILED_WEEKS[@]}"; do
        echo "    ✖  $w"
    done
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  ✖  SYSTEM NOT READY — ${#FAILED_WEEKS[@]} week(s) failed"
    echo "     Review the output above for details."
    echo "════════════════════════════════════════════════════"
    exit ${#FAILED_WEEKS[@]}
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  ✔  ALL VERIFICATIONS PASSED — System is healthy"
echo "════════════════════════════════════════════════════"
exit 0
