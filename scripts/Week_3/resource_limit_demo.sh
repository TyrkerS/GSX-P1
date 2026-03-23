#!/bin/bash
# resource_limit_demo.sh — Demostració de límits de recursos amb cgroups
# Inicia servei de workload (limitat a CPU i memòria), mostra estat, verifica límits, observa ús real
set -euo pipefail

SERVICE="p1-workload.service"

echo "=== RESOURCE LIMITS DEMONSTRATION ==="
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
echo "=== DEMONSTRATION COMPLETED ==="
