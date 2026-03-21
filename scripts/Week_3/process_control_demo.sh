#!/bin/bash
set -euo pipefail

echo "=== PROCESS CONTROL DEMO ==="
echo

echo "1) Creating CPU workload..."
yes > /dev/null &
PID=$!

echo "Process started with PID: $PID"
sleep 2

echo
echo "2) Showing top CPU processes..."
ps -eo pid,ppid,user,ni,%cpu,%mem,etime,cmd --sort=-%cpu | head -n 5
sleep 2

echo
echo "3) Pausing process with SIGSTOP..."
kill -STOP $PID
sleep 2

ps -p $PID -o pid,stat,cmd

echo
echo "4) Resuming process with SIGCONT..."
kill -CONT $PID
sleep 2

ps -p $PID -o pid,stat,%cpu,cmd

echo
echo "5) Changing priority with renice (requires root or process owner)..."
if [[ $EUID -eq 0 ]]; then
    renice +10 -p $PID
else
    sudo renice +10 -p $PID 2>/dev/null || echo "  (renice skipped — run as root for this step)"
fi
sleep 2

ps -p $PID -o pid,ni,%cpu,cmd

echo
echo "6) Sending SIGUSR1 (status report) to workload.sh..."
kill -SIGUSR1 $PID 2>/dev/null || echo "  Process already gone"
sleep 1

echo
echo "7) Sending SIGUSR2 (pause) to workload.sh..."
kill -SIGUSR2 $PID 2>/dev/null || echo "  Process already gone"
sleep 2
echo "   Process paused — CPU usage should drop:"
ps -p $PID -o pid,stat,%cpu,cmd 2>/dev/null || true

echo
echo "8) Sending SIGUSR2 again (resume)..."
kill -SIGUSR2 $PID 2>/dev/null || echo "  Process already gone"
sleep 2

echo
echo "9) Terminating process with SIGTERM (graceful)..."
kill -TERM $PID 2>/dev/null || true
sleep 2

if ps -p $PID > /dev/null 2>&1; then
    echo "Process still running, forcing kill with SIGKILL..."
    kill -KILL $PID
else
    echo "Process terminated gracefully."
fi

echo
echo "=== DEMO COMPLETED ==="
