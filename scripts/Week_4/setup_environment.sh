#!/bin/bash

PROFILE="/etc/profile.d/greendevcorp.sh"

echo "Setting up shared environment..."

sudo bash -c "cat > $PROFILE" << EOF
alias ll='ls -la'
alias gs='git status'

export PATH=\$PATH:/home/greendevcorp/bin
EOF

sudo chmod 644 $PROFILE

echo "Environment configured"