#!/bin/bash
# setup_storage.sh — Configuració de d'emmagatzemament extern
# Crea particions en disc, crea filesystem ext4, munta a /mnt/storage, afegeix entrada a /etc/fstab amb UUID
set -euo pipefail

DISK="${1:-/dev/sdb}"
PARTITION="${DISK}1"
MOUNT_POINT="/mnt/storage"
FS_TYPE="ext4"

echo "=== WEEK 5 STORAGE CONFIGURATION ==="
echo "Disk: $DISK"
echo "Partition: $PARTITION"
echo "Mount point: $MOUNT_POINT"
echo

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Usage: sudo ./setup_storage.sh /dev/sdb"
    exit 1
fi

# Check that the disk exists
if [[ ! -b "$DISK" ]]; then
    echo "ERROR: Disk $DISK does not exist."
    exit 1
fi

echo "1) Creating partition on $DISK..."
if [[ ! -b "$PARTITION" ]]; then
    echo -e "n\np\n1\n\n\nw" | fdisk "$DISK"
else
    echo "Partition $PARTITION already exists, skipping."
fi

sleep 2

echo
echo "2) Creating filesystem..."
if ! blkid "$PARTITION" >/dev/null 2>&1; then
    mkfs.$FS_TYPE "$PARTITION"
else
    echo "Filesystem already exists on $PARTITION, skipping."
fi

echo
echo "3) Creating mount point..."
mkdir -p "$MOUNT_POINT"

echo
echo "4) Getting UUID..."
UUID=$(blkid -s UUID -o value "$PARTITION")
echo "UUID=$UUID"

echo
echo "5) Adding fstab entry if missing..."
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $MOUNT_POINT $FS_TYPE defaults 0 2" >> /etc/fstab
else
    echo "fstab entry already exists, skipping."
fi

echo
echo "6) Mounting filesystem..."
mount -a

echo
echo "7) Verification:"
lsblk
echo
df -h | grep "$MOUNT_POINT" || true

echo
echo "=== STORAGE CONFIGURATION COMPLETED ==="
