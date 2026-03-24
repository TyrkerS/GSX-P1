#!/bin/bash
# setup_nfs.sh — Configure NFS server to share /mnt/storage/backups
# and a second VM (NFS client) to mount it.
#
# Run on the SERVER VM: sudo ./setup_nfs.sh server
# Run on the CLIENT VM: sudo ./setup_nfs.sh client <server_ip>
#
# The NFS share is read-only from the client side (backups directory),
# following least-privilege: clients can verify/read backups, not write them.

set -euo pipefail

EXPORT_DIR="/mnt/storage/backups"
NFS_MOUNT="/mnt/nfs_backups"  # Mount point on the client

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

MODE="${1:-}"
case "$MODE" in
    server) ;;
    client) SERVER_IP="${2:-}"; [[ -n "$SERVER_IP" ]] || die "Usage: $0 client <server_ip>" ;;
    *) echo "Usage: $0 server | $0 client <server_ip>"; exit 1 ;;
esac

[[ $EUID -eq 0 ]] || die "Must be run as root."

# ── SERVER SETUP ──────────────────────────────────────────────────────────────
if [[ "$MODE" == "server" ]]; then
    log "Installing NFS server..."
    apt-get update -qq
    apt-get install -y nfs-kernel-server

    # Verify the export directory exists and is on mounted storage
    mountpoint -q /mnt/storage || die "/mnt/storage not mounted. Run setup_storage.sh first."
    mkdir -p "$EXPORT_DIR"

    # Get client subnet (allow the whole NAT subnet)
    # In VirtualBox NAT, the host is typically 10.0.2.0/24
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

# ── CLIENT SETUP ──────────────────────────────────────────────────────────────
if [[ "$MODE" == "client" ]]; then
    log "Installing NFS client utilities..."
    apt-get update -qq
    apt-get install -y nfs-common

    mkdir -p "$NFS_MOUNT"

    log "Testing NFS mount from $SERVER_IP:$EXPORT_DIR..."
    # Temporary mount to verify connectivity
    if mountpoint -q "$NFS_MOUNT"; then
        log "$NFS_MOUNT already mounted — skipping temporary test."
    else
        mount -t nfs -o ro "$SERVER_IP:$EXPORT_DIR" "$NFS_MOUNT"
        log "NFS mount successful. Files visible:"
        ls -lh "$NFS_MOUNT" || true
        umount "$NFS_MOUNT"
    fi

    # Persistent mount via fstab
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
