#!/bin/bash
set -euo pipefail

SERVICE="p1-workload.service"

echo "=== RESOURCE LIMIT DEMO ==="
echo

echo "1) Starting workload service..."
sudo systemctl start $SERVICE
sleep 3

echo
echo "2) Checking service status..."
systemctl status $SERVICE --no-pager

echo
echo "3) Showing configured limits..."
systemctl show $SERVICE -p CPUQuota -p MemoryMax

echo
echo "4) Checking CPU usage (should be limited)..."
ps -eo pid,cmd,%cpu --sort=-%cpu | head -n 5

echo
echo "5) Showing cgroup usage..."
systemd-cgtop -b -n 1 | head -n 15

echo
echo "6) Stopping workload service..."
sudo systemctl stop $SERVICE

echo
echo "=== DEMO COMPLETED ==="
