#!/usr/bin/env bash
# Installs a NixOS host config onto a machine.
# Run from inside the flake directory on the live ISO (/iso/flake).
#
# Usage:
#   ./install.sh <host> --disk <disk-id>            # format + install
#   ./install.sh <host> --disk <disk-id> --wipe      # blkdiscard first
#
# For roach (dual-drive):
#   ./install.sh roach --disk <main-id> --home-disk <home-id>
#   ./install.sh roach --disk <main-id> --home-disk <home-id> --wipe
#
# <disk-id> is a /dev/disk/by-id/... path or a bare device like /dev/sda.
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <host> --disk <disk-id> [--home-disk <disk-id>] [--wipe]

Hosts: harry sebbers trunkie roach cornfield

Options:
  --disk <id>       Primary disk (required). /dev/disk/by-id/... or /dev/sdX
  --home-disk <id>  Second disk for /home (roach only)
  --wipe            blkdiscard all target disks before formatting

Examples:
  $0 cornfield --disk /dev/disk/by-id/ata-SAMSUNG_... --wipe
  $0 roach --disk /dev/disk/by-id/nvme-WD_... --home-disk /dev/disk/by-id/nvme-KINGSTON_... --wipe
EOF
  exit 1
}

[ $# -ge 3 ] || usage

HOST="$1"; shift

DISK=""
HOME_DISK=""
WIPE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --disk)      DISK="$2"; shift 2 ;;
    --home-disk) HOME_DISK="$2"; shift 2 ;;
    --wipe)      WIPE=true; shift ;;
    *)           echo "Unknown option: $1" >&2; usage ;;
  esac
done

[ -n "$DISK" ] || { echo "ERROR: --disk is required." >&2; usage; }

# Roach requires --home-disk
if [ "$HOST" = "roach" ] && [ -z "$HOME_DISK" ]; then
  echo "ERROR: roach has a dual-drive layout. Pass --home-disk <id>." >&2
  exit 1
fi

# Verify disks exist
ALL_DISKS=("$DISK")
[ -n "$HOME_DISK" ] && ALL_DISKS+=("$HOME_DISK")

for d in "${ALL_DISKS[@]}"; do
  if [ ! -e "$d" ]; then
    echo "ERROR: disk $d not found." >&2
    exit 1
  fi
done

echo "Host:       $HOST"
echo "Main disk:  $DISK -> $(readlink -f "$DISK")"
[ -n "$HOME_DISK" ] && echo "Home disk:  $HOME_DISK -> $(readlink -f "$HOME_DISK")"
echo "Wipe:       $WIPE"
echo
read -r -p "This will DESTROY all data on the target disk(s). Type 'WIPE' to continue: " confirm
[ "$confirm" = "WIPE" ] || { echo "Aborted."; exit 1; }

# ── LUKS passphrase ──────────────────────────────────────────────────
if [ ! -s /tmp/disk-password ]; then
  echo
  echo "Enter LUKS passphrase:"
  read -r -s pass1
  echo "Confirm passphrase:"
  read -r -s pass2
  [ "$pass1" = "$pass2" ] || { echo "Passphrases do not match."; exit 1; }
  printf '%s' "$pass1" | sudo tee /tmp/disk-password >/dev/null
  sudo chmod 600 /tmp/disk-password
  unset pass1 pass2
fi

# ── Phase 0: close stale LUKS + optional wipe ───────────────────────
echo
echo "==> Closing any stale LUKS mappings"
for name in cryptroot crypthome; do
  if [ -e "/dev/mapper/$name" ]; then
    sudo cryptsetup close "$name" || true
  fi
done
sudo umount -R /mnt 2>/dev/null || true

if $WIPE; then
  echo
  echo "==> Wiping disks (blkdiscard)"
  for d in "${ALL_DISKS[@]}"; do
    real="$(readlink -f "$d")"
    echo "  blkdiscard $real"
    sudo blkdiscard -f "$real"
  done
fi

# ── Install via disko-install ────────────────────────────────────────
echo
echo "==> Running disko-install (format + nixos-install)"

DISKO_ARGS=(
  sudo disko-install
  --flake ".#${HOST}"
  --disk main "$DISK"
)

# Roach dual-drive: pass the home disk too
if [ -n "$HOME_DISK" ]; then
  DISKO_ARGS+=(--disk home "$HOME_DISK")
fi

"${DISKO_ARGS[@]}"

# ── Cleanup ─────────────────────────────────────────────────────────
echo
echo "==> Unmounting and closing LUKS"
sudo umount -R /mnt || true
sudo cryptsetup close cryptroot 2>/dev/null || true
sudo cryptsetup close crypthome 2>/dev/null || true

echo
echo "Done. You can now reboot into ${HOST}."
