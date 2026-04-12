#!/usr/bin/env bash
# Cleans up any state left by a previous disko-install attempt on the
# asus-tuf, then wipes both NVMe drives so the installer can start fresh.
# Run on the live ISO. DESTROYS ALL DATA on both drives.
set -euo pipefail

MAIN_ID="nvme-WD_PC_SN5000S_SDEQNSJ-1T00-1002_25184R800947"
HOME_ID="nvme-KINGSTON_SNV3S1000G_50026B76873F13D6"

MAIN_DISK="/dev/disk/by-id/${MAIN_ID}"
HOME_DISK="/dev/disk/by-id/${HOME_ID}"

for d in "$MAIN_DISK" "$HOME_DISK"; do
  if [ ! -e "$d" ]; then
    echo "ERROR: $d not found. Update the *_ID vars in this script." >&2
    exit 1
  fi
done

MAIN_REAL="$(readlink -f "$MAIN_DISK")"
HOME_REAL="$(readlink -f "$HOME_DISK")"

echo "About to WIPE both drives:"
echo "  main: $MAIN_DISK -> $MAIN_REAL"
echo "  home: $HOME_DISK -> $HOME_REAL"
echo
read -r -p "Type 'WIPE' to continue: " confirm
[ "$confirm" = "WIPE" ] || { echo "Aborted."; exit 1; }

echo
echo "==> Unmounting anything under /mnt"
sudo umount -R /mnt/target 2>/dev/null || true
sudo umount -R /mnt/disko-install-root 2>/dev/null || true
sudo umount -R /mnt 2>/dev/null || true

echo "==> Closing any open LUKS mappings"
for name in cryptroot crypthome; do
  if [ -e "/dev/mapper/$name" ]; then
    sudo cryptsetup close "$name" || true
  fi
done

echo "==> Removing any leftover device-mapper entries"
sudo dmsetup remove_all 2>/dev/null || true

echo "==> Wiping filesystem signatures"
sudo wipefs -a "$MAIN_REAL" "$HOME_REAL"

echo "==> Zapping partition tables"
sudo sgdisk --zap-all "$MAIN_REAL"
sudo sgdisk --zap-all "$HOME_REAL"

echo "==> Re-reading partition tables"
sudo partprobe "$MAIN_REAL" "$HOME_REAL" 2>/dev/null || true

echo "==> Removing stale LUKS password file"
sudo rm -f /tmp/disk-password

echo
echo "Done. Both drives are clean. You can now run ./install-asus-tuf.sh"
