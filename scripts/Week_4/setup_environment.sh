#!/bin/bash
# setup_environment.sh — Configuració de variables d'entorn compartides
# Crea /etc/profile.d/greendevcorp.sh amb alias i afegeix /home/greendevcorp/bin al PATH
set -euo pipefail

PROFILE="/etc/profile.d/greendevcorp.sh"

echo "Configuring shared environment..."

sudo bash -c "cat > $PROFILE" << EOF
# Useful aliases for GreenDevCorp team
alias ll='ls -la'
alias gs='git status'

# Add project bin to PATH
export PATH=\$PATH:/home/greendevcorp/bin
EOF

sudo chmod 644 $PROFILE

echo "Environment configured"