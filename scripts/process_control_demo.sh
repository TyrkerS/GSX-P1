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
echo "5) Changing priority with renice..."
sudo renice +10 -p $PID
sleep 2

ps -p $PID -o pid,ni,%cpu,cmd

echo
echo "6) Terminating process with SIGTERM..."
kill -TERM $PID
sleep 2

if ps -p $PID > /dev/null
then
    echo "Process still running, forcing kill..."
    kill -KILL $PID
else
    echo "Process terminated successfully."
fi

echo
echo "=== DEMO COMPLETED ==="
