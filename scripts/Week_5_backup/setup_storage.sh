#!/bin/bash
set -euo pipefail

DISK="${1:-/dev/sdb}"
PARTITION="${DISK}1"
MOUNT_POINT="/mnt/storage"
FS_TYPE="ext4"

echo "=== WEEK 5 STORAGE SETUP ==="
echo "Disk: $DISK"
echo "Partition: $PARTITION"
echo "Mount point: $MOUNT_POINT"
echo

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Use: sudo ./setup_storage.sh /dev/sdb"
    exit 1
fi

# Check disk exists
if [[ ! -b "$DISK" ]]; then
    echo "ERROR: Disk $DISK does not exist."
    exit 1
fi

echo "1) Creating partition on $DISK..."
if [[ ! -b "$PARTITION" ]]; then
    echo -e "n\np\n1\n\n\nw" | fdisk "$DISK"
    # Wait for kernel to register the new partition
    partprobe "$DISK" 2>/dev/null || true
    udevadm settle
    sleep 2
else
    echo "Partition $PARTITION already exists, skipping."
fi

sleep 1

echo
echo "2) Creating filesystem..."
if ! blkid "$PARTITION" >/dev/null 2>&1; then
    mkfs.$FS_TYPE "$PARTITION"
    udevadm settle
    sleep 1
else
    echo "Filesystem already exists on $PARTITION, skipping."
fi

echo
echo "3) Creating mount point..."
mkdir -p "$MOUNT_POINT"

echo
echo "4) Getting UUID..."
# Force kernel to re-read partition table (fixes stale state from previous runs)
blockdev --rereadpt "$DISK" 2>/dev/null || true
udevadm trigger --subsystem-match=block
udevadm settle --timeout=15

# Bypass blkid cache to get fresh UUID
UUID=$(blkid --cache-file /dev/null -s UUID -o value "$PARTITION" 2>/dev/null || true)

# If still empty, force re-format to generate a new UUID
if [[ -z "$UUID" ]]; then
    echo "UUID still empty after settle — force-reformatting $PARTITION..."
    mkfs.ext4 -F "$PARTITION"
    udevadm settle --timeout=10
    UUID=$(blkid --cache-file /dev/null -s UUID -o value "$PARTITION" 2>/dev/null || true)
fi

echo "UUID=$UUID"

if [[ -z "$UUID" ]]; then
    echo "ERROR: Could not get UUID for $PARTITION even after reformat." >&2
    echo "       Try: reboot, then run setup_all.sh --start-week 5" >&2
    exit 1
fi

echo
echo "5) Adding/updating entry in /etc/fstab..."
# Remove any existing entry for this mount point (including stale blank-UUID entries)
sed -i "\|$MOUNT_POINT|d" /etc/fstab
echo "UUID=$UUID $MOUNT_POINT $FS_TYPE defaults 0 2" >> /etc/fstab
echo "fstab updated with UUID=$UUID"

echo
echo "6) Mounting filesystem..."
mount -a

echo
echo "7) Verification:"
lsblk
echo
df -h | grep "$MOUNT_POINT" || true

echo
echo "=== STORAGE SETUP COMPLETED ==="
