#!/bin/bash
set -euo pipefail

USER_NAME="gsx"
BASE_DIR="/opt/P1"
BACKUP_DIR="/var/backups/P1"
ETC_DIR="/etc/P1"
SSH_PORT="22222"
SSH_PUBKEY=""  # establert via argument --ssh-pubkey

# Parseig dels arguments --ssh-pubkey opcionals
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ssh-pubkey) SSH_PUBKEY="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done


# Comprovació de permisos root
if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: su - OR sudo ./bootstrap.sh"
  exit 1
fi

log() {
    echo
    echo "==> $1"
}

# Actualització del sistema
update_system() {
    log "Updating system..."
    apt update   # -y no és vàlid per a 'update', només per a 'install'
}

# Instal·lació de paquets requerits
install_packages() {
    log "Installing required packages..."
    apt install -y \
        sudo \
        openssh-server \
        vim \
        curl \
        htop \
        tree \
        unattended-upgrades
}

# Configuració de actualitzacions automàtiques
configure_auto_updates() {
    log "Enabling automatic security updates..."
    dpkg-reconfigure -f noninteractive unattended-upgrades
}

# Configuració de sudo
configure_sudo() {
    log "Configuring sudo..."

    if ! id -nG "$USER_NAME" | grep -qw sudo; then
        /usr/sbin/usermod -aG sudo "$USER_NAME"
        echo "User added to sudo group."
    fi
}


setup_authorized_keys() {
    log "Setting up SSH authorized_keys for $USER_NAME..."

    local SSH_DIR="/home/$USER_NAME/.ssh"
    local AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chown "$USER_NAME:$USER_NAME" "$SSH_DIR"

    if [[ -n "$SSH_PUBKEY" ]]; then
        # Afegir clau si no està present
        if ! grep -qF "$SSH_PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
            echo "$SSH_PUBKEY" >> "$AUTH_KEYS"
            echo "Public key added to $AUTH_KEYS"
        else
            echo "Public key already present — skipping."
        fi
        chmod 600 "$AUTH_KEYS"
        chown "$USER_NAME:$USER_NAME" "$AUTH_KEYS"
    else
        echo "No --ssh-pubkey provided. Password auth will remain enabled."
        echo "Add your public key manually and re-run, or pass --ssh-pubkey."
    fi
}

# Configuració de SSH
configure_ssh() {
    log "Configuring SSH..."

    systemctl enable ssh
    systemctl start ssh

    # Enfortir la configuració SSH
    sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    # Desabilitar autenticació per contrasenya només si tenim una clau pública instal·lada
    if [[ -s "/home/$USER_NAME/.ssh/authorized_keys" ]]; then
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        echo "Password authentication disabled (key installed)."
    else
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        echo "WARNING: Password authentication left ENABLED (no key installed)."
        echo "         Run again with --ssh-pubkey to harden."
    fi

    systemctl restart ssh
}

# Creació d'estructura de directoris
create_structure() {
    log "Creating directory structure..."

    mkdir -p "$BASE_DIR/scripts"
    mkdir -p "$BASE_DIR/docs"
    mkdir -p "$BASE_DIR/logs"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$ETC_DIR"

    chown -R "$USER_NAME":"$USER_NAME" "$BASE_DIR"
    chown -R "$USER_NAME":"$USER_NAME" "$BACKUP_DIR"
}


# Inicialització del repositori Git
initialize_git() {
    log "Initializing Git repository in $BASE_DIR"

    if [ ! -d "$BASE_DIR/.git" ]; then
        sudo -u "$USER_NAME" git -C "$BASE_DIR" init
        sudo -u "$USER_NAME" git -C "$BASE_DIR" config user.name "GreenDevCorp Admin"
        sudo -u "$USER_NAME" git -C "$BASE_DIR" config user.email "admin@greendevcorp.local"

        
        cat > "$BASE_DIR/.gitignore" << 'EOF'
*.log
backups/
*.tar.gz
*.tar.gz.gpg
*.key
*.pem
authorized_keys
EOF
        chown "$USER_NAME:$USER_NAME" "$BASE_DIR/.gitignore"

        sudo -u "$USER_NAME" git -C "$BASE_DIR" add .
        sudo -u "$USER_NAME" git -C "$BASE_DIR" commit -m "Baseline administrative structure"
    else
        log "Git repository already initialized — skipping."
    fi
}


# Funció principal
main() {
    log "Starting Week 1 bootstrap..."

    update_system
    install_packages
    configure_auto_updates
    configure_sudo
    create_structure     
    setup_authorized_keys
    configure_ssh        
    initialize_git

    log "Bootstrap completed successfully."
    log "Next steps:"
    log "  1. Test SSH: ssh -p $SSH_PORT $USER_NAME@<host_ip>"
    log "  2. Run verify_setup.sh to confirm all checks pass"
    log "  3. If password auth is still enabled, re-run with --ssh-pubkey"
}

main "$@"