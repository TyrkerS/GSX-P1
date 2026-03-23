#!/bin/bash
# setup_pam_limits.sh — Configuració de límits de recursos per usuari via PAM
# Escriu límits a /etc/security/limits.d/greendevcorp.conf
# Aquests límits s'apliquen quan els usuaris fan login via PAM (SSH, login, su)
#
# Límits aplicats per desenvolupador:
#   nproc   (màx processos)       → soft 100, hard 200
#   nofile  (màx fitxers oberts)  → soft 1024, hard 4096
#   memlock (màx memòria blocada) → soft 64MB, hard 128MB
#   cpu     (temps CPU minuts)    → soft 60, hard 120
#
# Ús: sudo ./setup_pam_limits.sh
set -euo pipefail

LIMITS_FILE="/etc/security/limits.d/greendevcorp.conf"
GROUP="greendevcorp"

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root." >&2; exit 1; }

echo "Configuring PAM resource limits for group '$GROUP'..."

# Idempotent: overwrite with canonical config each time
cat > "$LIMITS_FILE" << 'EOF'
# GreenDevCorp developer limits
# Format: <domain> <type> <item> <value>
#   domain:  username, @groupname, or * (all)
#   type:    soft (warning/default), hard (absolute maximum)

# Maximum number of processes per user (prevents fork bombs)
@greendevcorp    soft    nproc       100
@greendevcorp    hard    nproc       200

# Maximum open file descriptors (important for apps with many connections)
@greendevcorp    soft    nofile      1024
@greendevcorp    hard    nofile      4096

# Maximum locked memory in KB (64MB soft, 128MB hard)
@greendevcorp    soft    memlock     65536
@greendevcorp    hard    memlock     131072

# Maximum CPU time in minutes (soft=warning, hard=kill)
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
