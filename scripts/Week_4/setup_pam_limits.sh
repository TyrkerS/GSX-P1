#!/bin/bash
# setup_pam_limits.sh — Configure per-user resource limits via PAM.
# Writes limits to /etc/security/limits.d/greendevcorp.conf
# These limits are enforced when users log in via PAM (SSH, login, su).
#
# Limits applied per developer:
#   nproc   (max processes)     → soft 100, hard 200
#   nofile  (max open files)    → soft 1024, hard 4096
#   memlock (max locked memory) → soft 64MB, hard 128MB
#   cpu     (CPU time minutes)  → soft 60, hard 120
#
# Usage: sudo ./setup_pam_limits.sh
set -euo pipefail

LIMITS_FILE="/etc/security/limits.d/greendevcorp.conf"
GROUP="greendevcorp"

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root." >&2; exit 1; }

echo "Configuring PAM resource limits for group '$GROUP'..."

# Idempotent: overwrite with the canonical config each run
cat > "$LIMITS_FILE" << 'EOF'
# GreenDevCorp developer limits
# Format: <domain> <type> <item> <value>
#   domain: username, @groupname, or * (all)
#   type:   soft (warning/default), hard (absolute max)

# Max number of processes per user (prevents fork bombs)
@greendevcorp    soft    nproc       100
@greendevcorp    hard    nproc       200

# Max open file descriptors (important for apps that open many connections)
@greendevcorp    soft    nofile      1024
@greendevcorp    hard    nofile      4096

# Max locked memory in KB (64MB soft, 128MB hard)
@greendevcorp    soft    memlock     65536
@greendevcorp    hard    memlock     131072

# Max CPU time in minutes (soft=warning, hard=kill)
@greendevcorp    soft    cpu         60
@greendevcorp    hard    cpu         120
EOF

chmod 644 "$LIMITS_FILE"

echo "Limits written to $LIMITS_FILE"
echo ""
echo "To verify limits for a user, run:"
echo "  sudo -u dev1 bash -c 'ulimit -a'"
echo ""
echo "Note: limits apply at login time. Existing sessions are not affected."
