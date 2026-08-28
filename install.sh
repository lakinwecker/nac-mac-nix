#!/usr/bin/env bash
# Installs a NixOS host config onto a machine.
# Run from inside the flake directory on the live ISO (/iso/flake).
#
# Usage:
#   ./install.sh <host> --disk <name>=<disk-id> [--disk <name>=<disk-id> ...] [--wipe]
#
# Each <name> is a disk declared in that host's disko config. Single-disk hosts
# declare one disk called "main", so the name may be omitted:
#   ./install.sh cornfield --disk /dev/disk/by-id/ata-SAMSUNG_...
#
# Dual-drive hosts declare "main" and "home"; --home-disk is shorthand for
# --disk home=...:
#   ./install.sh gratch --disk <main-id> --home-disk <home-id>
#
# Four-disk hosts name every member explicitly:
#   ./install.sh trunkie --disk root0=<id> --disk root1=<id> \
#                        --disk home0=<id> --disk home1=<id>
#
# <disk-id> is a /dev/disk/by-id/... path or a bare device like /dev/sda.
# Prefer by-id: NVMe enumeration order is not stable across boots.
set -euo pipefail

NIX_OPTS=(--extra-experimental-features nix-command)

usage() {
  cat >&2 <<EOF
Usage: $0 <host> --disk [<name>=]<disk-id> [--disk <name>=<disk-id> ...] [--wipe]

Hosts: $(nix eval --raw "${NIX_OPTS[@]}" \
    --file machines.nix --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)' 2>/dev/null || echo "(run 'nix eval --file machines.nix' to list)")

Options:
  --disk [<name>=]<id>  A disk declared in the host's disko config. Repeatable.
                        Bare <id> with no name= prefix means "main".
  --home-disk <id>      Shorthand for --disk home=<id>
  --wipe                blkdiscard all target disks before formatting

Examples:
  $0 cornfield --disk /dev/disk/by-id/ata-SAMSUNG_... --wipe
  $0 roach --disk <main-id> --home-disk <home-id> --wipe
  $0 trunkie --disk root0=<id> --disk root1=<id> --disk home0=<id> --disk home1=<id>
EOF
  exit 1
}

[ $# -ge 3 ] || usage

HOST="$1"; shift

DISK_NAMES=()
DISK_PATHS=()
WIPE=false

add_disk() {
  local name="$1" path="$2" existing
  for existing in ${DISK_NAMES+"${DISK_NAMES[@]}"}; do
    [ "$existing" = "$name" ] && { echo "ERROR: --disk $name given twice." >&2; exit 1; }
  done
  DISK_NAMES+=("$name")
  DISK_PATHS+=("$path")
}

while [ $# -gt 0 ]; do
  case "$1" in
    --disk)
      [ $# -ge 2 ] || { echo "ERROR: --disk needs a value." >&2; usage; }
      case "$2" in
        *=*) add_disk "${2%%=*}" "${2#*=}" ;;
        *)   add_disk main "$2" ;;
      esac
      shift 2 ;;
    --home-disk)
      [ $# -ge 2 ] || { echo "ERROR: --home-disk needs a value." >&2; usage; }
      add_disk home "$2"; shift 2 ;;
    --wipe) WIPE=true; shift ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[ ${#DISK_NAMES[@]} -gt 0 ] || { echo "ERROR: at least one --disk is required." >&2; usage; }

# ── Check the supplied names against the host's disko config ─────────
# Read the disko file directly rather than evaluating the whole NixOS config:
# it is pure, needs no flake and no nixpkgs, and takes milliseconds. These
# files only ever call lib.mkDefault, so a stub lib suffices. If that stops
# being true the eval fails and we skip validation rather than block install.
declared=$(nix eval --json --impure "${NIX_OPTS[@]}" --expr "
  let
    machines  = import ./machines.nix;
    entry     = machines.\"$HOST\" or (throw \"unknown host: $HOST\");
    diskoPath = entry.diskoConfig or ./disko-config.nix;
    cfg       = import diskoPath { lib = { mkDefault = x: x; }; };
  in builtins.attrNames cfg.disko.devices.disk
" 2>/dev/null || true)

if [ -n "$declared" ]; then
  # ["home0","home1"] -> newline-separated names
  mapfile -t DECLARED < <(printf '%s' "$declared" | tr -d '[]"' | tr ',' '\n' | grep -v '^$')

  missing=()
  for want in "${DECLARED[@]}"; do
    found=false
    for got in "${DISK_NAMES[@]}"; do [ "$got" = "$want" ] && found=true; done
    $found || missing+=("$want")
  done
  unknown=()
  for got in "${DISK_NAMES[@]}"; do
    found=false
    for want in "${DECLARED[@]}"; do [ "$got" = "$want" ] && found=true; done
    $found || unknown+=("$got")
  done

  if [ ${#missing[@]} -gt 0 ] || [ ${#unknown[@]} -gt 0 ]; then
    echo "ERROR: disk arguments do not match $HOST's disko config." >&2
    echo "  declared: ${DECLARED[*]}" >&2
    echo "  supplied: ${DISK_NAMES[*]}" >&2
    [ ${#missing[@]} -gt 0 ] && echo "  missing:  ${missing[*]}" >&2
    [ ${#unknown[@]} -gt 0 ] && echo "  unknown:  ${unknown[*]}" >&2
    exit 1
  fi
else
  echo "WARNING: could not read $HOST's disko config; skipping disk-name check." >&2
fi

# ── Verify disks exist ───────────────────────────────────────────────
for d in "${DISK_PATHS[@]}"; do
  [ -e "$d" ] || { echo "ERROR: disk $d not found." >&2; exit 1; }
done

echo "Host:  $HOST"
for i in "${!DISK_NAMES[@]}"; do
  printf '  %-6s %s -> %s\n' "${DISK_NAMES[$i]}" "${DISK_PATHS[$i]}" "$(readlink -f "${DISK_PATHS[$i]}")"
done
echo "Wipe:  $WIPE"
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

# ── Phase 0: close stale LUKS on the target disks + optional wipe ────
# Only close mappings backed by a disk we are about to format, so a container
# the operator opened by hand to read another drive is left alone.
echo
echo "==> Closing any stale LUKS mappings on the target disks"
sudo umount -R /mnt 2>/dev/null || true
for d in "${DISK_PATHS[@]}"; do
  real="$(readlink -f "$d")"
  while read -r mapping; do
    [ -n "$mapping" ] || continue
    echo "  cryptsetup close $mapping"
    sudo cryptsetup close "$mapping" || true
  done < <(lsblk -nlo NAME,TYPE "$real" 2>/dev/null | awk '$2 == "crypt" { print $1 }')
done

if $WIPE; then
  echo
  echo "==> Wiping disks (blkdiscard)"
  for d in "${DISK_PATHS[@]}"; do
    real="$(readlink -f "$d")"
    echo "  blkdiscard $real"
    sudo blkdiscard -f "$real"
  done
fi

# ── Install via disko-install ────────────────────────────────────────
echo
echo "==> Running disko-install (format + nixos-install)"

DISKO_ARGS=(sudo disko-install --flake ".#${HOST}")
for i in "${!DISK_NAMES[@]}"; do
  DISKO_ARGS+=(--disk "${DISK_NAMES[$i]}" "${DISK_PATHS[$i]}")
done

"${DISKO_ARGS[@]}"

# ── Cleanup ─────────────────────────────────────────────────────────
echo
echo "==> Unmounting and closing LUKS"
sudo umount -R /mnt || true
for d in "${DISK_PATHS[@]}"; do
  real="$(readlink -f "$d")"
  while read -r mapping; do
    [ -n "$mapping" ] || continue
    sudo cryptsetup close "$mapping" || true
  done < <(lsblk -nlo NAME,TYPE "$real" 2>/dev/null | awk '$2 == "crypt" { print $1 }')
done

echo
echo "Done. You can now reboot into ${HOST}."
