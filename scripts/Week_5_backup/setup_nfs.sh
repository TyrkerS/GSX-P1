#!/bin/bash
set -euo pipefail

EXPORT_DIR="/mnt/storage/backups"
NFS_MOUNT="/mnt/nfs_backups"  

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

MODE="${1:-}"
case "$MODE" in
    server) ;;
    client) SERVER_IP="${2:-}"; [[ -n "$SERVER_IP" ]] || die "Usage: $0 client <server_ip>" ;;
    *) echo "Usage: $0 server | $0 client <server_ip>"; exit 1 ;;
esac

[[ $EUID -eq 0 ]] || die "Must be run as root."

if [[ "$MODE" == "server" ]]; then
    log "Installing NFS server..."
    apt-get update -qq
    apt-get install -y nfs-kernel-server

    mountpoint -q /mnt/storage || die "/mnt/storage not mounted. Run setup_storage.sh first."
    mkdir -p "$EXPORT_DIR"

    CLIENT_SUBNET="10.0.2.0/24"

    log "Configuring NFS export: $EXPORT_DIR → $CLIENT_SUBNET (read-only)"
    EXPORT_LINE="$EXPORT_DIR $CLIENT_SUBNET(ro,sync,no_subtree_check,no_root_squash)"

    if grep -qF "$EXPORT_DIR" /etc/exports; then
        log "/etc/exports already has entry for $EXPORT_DIR — skipping."
    else
        echo "$EXPORT_LINE" >> /etc/exports
    fi

    log "Applying NFS exports..."
    exportfs -ra

    log "Enabling and starting NFS server..."
    systemctl enable nfs-kernel-server
    systemctl restart nfs-kernel-server

    log "NFS exports:"
    exportfs -v

    log ""
    log "=== NFS SERVER READY ==="
    log "Clients can mount: <this_server_ip>:$EXPORT_DIR → $NFS_MOUNT"
fi

if [[ "$MODE" == "client" ]]; then
    log "Installing NFS client utilities..."
    apt-get update -qq
    apt-get install -y nfs-common

    mkdir -p "$NFS_MOUNT"

    log "Testing NFS mount from $SERVER_IP:$EXPORT_DIR..."
    if mountpoint -q "$NFS_MOUNT"; then
        log "$NFS_MOUNT already mounted — skipping temporary test."
    else
        mount -t nfs -o ro "$SERVER_IP:$EXPORT_DIR" "$NFS_MOUNT"
        log "NFS mount successful. Files visible:"
        ls -lh "$NFS_MOUNT" || true
        umount "$NFS_MOUNT"
    fi

    FSTAB_LINE="$SERVER_IP:$EXPORT_DIR $NFS_MOUNT nfs ro,_netdev,auto 0 0"
    if grep -qF "$SERVER_IP:$EXPORT_DIR" /etc/fstab; then
        log "fstab already has NFS entry — skipping."
    else
        log "Adding persistent NFS mount to /etc/fstab..."
        echo "$FSTAB_LINE" >> /etc/fstab
    fi

    log "Mounting all fstab entries..."
    mount -a

    log "NFS mount status:"
    mountpoint -q "$NFS_MOUNT" && echo "Mounted: $NFS_MOUNT" || echo "NOT mounted: $NFS_MOUNT"

    log ""
    log "=== NFS CLIENT READY ==="
    log "Backup files accessible at: $NFS_MOUNT"
fi
