#!/bin/bash
# workload.sh — CPU workload script for Week 3 process management demos.
# Runs a continuous CPU load loop and handles signals gracefully.
#
# Signals handled:
#   SIGTERM  → Graceful shutdown (saves state and exits cleanly)
#   SIGUSR1  → Print a status report (PID, uptime, iteration count)
#   SIGUSR2  → Toggle pause/resume of the CPU load
#
# Usage: ./workload.sh &
#        kill -SIGUSR1 <PID>   # request status report
#        kill -SIGUSR2 <PID>   # pause/resume
#        kill -SIGTERM <PID>   # graceful stop
set -euo pipefail

START_TIME=$(date +%s)
ITERATION=0
PAUSED=false
RUNNING=true

# ── Signal handlers ───────────────────────────────────────────────────────────

handle_sigterm() {
    echo "[workload] SIGTERM received — shutting down gracefully" >&2
    echo "[workload] Completed $ITERATION iterations over $(($(date +%s) - START_TIME))s" >&2
    RUNNING=false
}

handle_sigusr1() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    echo "[workload] STATUS: PID=$$  iterations=$ITERATION  uptime=${elapsed}s  paused=$PAUSED" >&2
}

handle_sigusr2() {
    if $PAUSED; then
        echo "[workload] SIGUSR2 received — resuming CPU load" >&2
        PAUSED=false
    else
        echo "[workload] SIGUSR2 received — pausing CPU load" >&2
        PAUSED=true
    fi
}

trap 'handle_sigterm' SIGTERM
trap 'handle_sigusr1' SIGUSR1
trap 'handle_sigusr2' SIGUSR2

echo "[workload] Started — PID=$$" >&2
echo "[workload] Send SIGUSR1 for status, SIGUSR2 to pause/resume, SIGTERM to stop" >&2

# ── Main loop ─────────────────────────────────────────────────────────────────
while $RUNNING; do
    if $PAUSED; then
        sleep 1
    else
        # Burn CPU in small bursts so signal handlers can fire between iterations
        for _ in $(seq 1 10000); do : ; done
        ITERATION=$((ITERATION + 1))
    fi
done

echo "[workload] Clean exit after $ITERATION iterations." >&2

