#!/bin/bash
# diagnose.sh — Script de diagnòstic del sistema per analitzar processos
# Ofereix múltiples modes: snapshot (estat ràpid), top (processos més consumidors), tree (arbre de processos), pid (mètriques detallades d'un PID)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./diagnose.sh snapshot [N]
  ./diagnose.sh top [N]
  ./diagnose.sh tree
  ./diagnose.sh pid <PID>

Commands:
  snapshot [N]   Quick system snapshot + top CPU/MEM (N default=10)
  top [N]        Show top CPU and top MEM processes (N default=10)
  tree           Show process tree (requires pstree -> psmisc package)
  pid <PID>      Show detailed metrics for a PID (ps + /proc + I/O)

Examples:
  ./diagnose.sh snapshot
  ./diagnose.sh top 15
  ./diagnose.sh tree
  ./diagnose.sh pid 1
EOF
}

cmd_snapshot() {
  local N="${1:-10}"
  echo "=== SYSTEM SNAPSHOT ==="
  echo "Time: $(date)"
  echo "Uptime/load: $(uptime)"
  echo

  echo "== Memory =="
  free -h
  echo

  echo "== Disk usage =="
  df -h | head -n 20
  echo

  echo "== vmstat (CPU/IO pressure) =="
  # r: executable, b: blocked, bi/bo: IO, us/sy/id: CPU
  vmstat 1 3
  echo

  cmd_top "$N"
}

cmd_top() {
  local N="${1:-10}"
  echo "=== TOP $N CPU ==="
  ps -eo pid,ppid,user,ni,%cpu,%mem,etime,cmd --sort=-%cpu | head -n "$((N+1))"
  echo
  echo "=== TOP $N MEM ==="
  ps -eo pid,ppid,user,ni,%cpu,%mem,etime,cmd --sort=-%mem | head -n "$((N+1))"
}

cmd_tree() {
  if ! command -v pstree >/dev/null 2>&1; then
    echo "ERROR: pstree not found. Install it with:"
    echo "  sudo apt install -y psmisc"
    exit 1
  fi
  echo "=== PROCESS TREE (pstree) ==="
  pstree -ap
}

cmd_pid() {
  local PID="${1:-}"
  if [[ -z "$PID" ]]; then
    echo "ERROR: missing PID"
    usage
    exit 1
  fi
  if [[ ! -d "/proc/$PID" ]]; then
    echo "ERROR: PID $PID does not exist."
    exit 1
  fi

  echo "=== BASIC INFO (ps) ==="
  ps -p "$PID" -o pid,ppid,pgid,sid,user,stat,ni,%cpu,%mem,etime,cmd
  echo

  echo "=== /proc/$PID/status (selected) ==="
  grep -E '^(Name|State|PPid|Uid|Gid|Threads|VmRSS|VmSize|VmPeak|FDSize|voluntary_ctxt_switches|nonvoluntary_ctxt_switches):' "/proc/$PID/status" || true
  echo

  echo "=== /proc/$PID/io (selected) ==="
  if [[ -r "/proc/$PID/io" ]]; then
    grep -E '^(read_bytes|write_bytes|syscr|syscw):' "/proc/$PID/io" || true
  else
    echo "No permission to read /proc/$PID/io. Try: sudo ./diagnose.sh pid $PID"
  fi
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    snapshot) cmd_snapshot "${1:-10}" ;;
    top)      cmd_top "${1:-10}" ;;
    tree)     cmd_tree ;;
    pid)      cmd_pid "${1:-}" ;;
    -h|--help|"") usage; exit 0 ;;
    *) echo "ERROR: unknown command '$cmd'"; usage; exit 1 ;;
  esac
}

main "$@"
