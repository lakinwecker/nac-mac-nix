#!/usr/bin/env bash
set -euo pipefail

hosts=($(nix eval --raw --extra-experimental-features nix-command \
  --file machines.nix --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'))
nix_cmd=(nix --extra-experimental-features 'nix-command flakes')
inhibit=(systemd-inhibit --what=idle:sleep --who=build.sh --why "NixOS build in progress")

usage() {
  cat >&2 <<EOF
Usage: $0 <action> [args...]

Build actions (take zero or more hosts):
  --iso      [host...]  Build installer ISO(s)           (output: result-<host>/)
  --build    [host...]  Build system toplevel (no switch)
  --switch   [host]     Build and switch (nixos-rebuild switch)
  --boot     [host]     Build and activate on next boot  (nixos-rebuild boot)
  --test     [host]     Build and activate now, no boot entry
  --dry      [host...]  Dry-run build (evaluation only)

Installer actions (take one host, run from a live ISO):
  --install  <host> [--disk <name> <device>]...
      Wipe disks and install NixOS. For hosts with disks hardcoded in their
      disko config (roach), no --disk flags are needed. Otherwise pass
      --disk main /dev/disk/by-id/... to override the default device.
  --wipe     <host> [--disk <name> <device>]...
      Wipe disks without installing. Use to recover from a failed install.

Hosts: ${hosts[*]}
  If no host is given for a build action, defaults to all hosts for
  --iso/--dry, or the current hostname for --switch/--boot/--test/--build.

Examples:
  $0 --switch
  $0 --iso roach
  $0 --dry harry gratch
  $0 --install roach
  $0 --install harry --disk main /dev/disk/by-id/nvme-SAMSUNG_...
  $0 --wipe roach
EOF
  exit 1
}

validate_host() {
  local host="$1"
  for valid in "${hosts[@]}"; do
    [ "$host" = "$valid" ] && return 0
  done
  echo "Unknown host: $host" >&2
  echo "Valid hosts: ${hosts[*]}" >&2
  exit 1
}

current_host() {
  local hn
  hn=$(hostname)
  for valid in "${hosts[@]}"; do
    [ "$hn" = "$valid" ] && echo "$valid" && return 0
  done
  echo "Current hostname '$hn' doesn't match any known host." >&2
  echo "Specify a host explicitly." >&2
  exit 1
}

# Reads the disko config for a host and applies name=path overrides.
# Emits "name<TAB>path" lines on stdout, one per disk.
# Usage: read_disks <host> [override_name=override_path]...
read_disks() {
  local host="$1"; shift
  local json
  json=$("${nix_cmd[@]}" eval --json \
    ".#nixosConfigurations.${host}.config.disko.devices.disk" \
    --apply 'disks: builtins.mapAttrs (_: d: d.device) disks' 2>/dev/null) \
    || { echo "ERROR: failed to evaluate disko config for '${host}'" >&2; return 1; }
  local overrides_json='{}'
  if [ $# -gt 0 ]; then
    overrides_json=$(printf '%s\n' "$@" \
      | jq -R 'split("=") | {key: .[0], value: .[1]}' \
      | jq -s 'from_entries')
  fi
  jq -r --argjson overrides "$overrides_json" '
    . + $overrides
    | to_entries[]
    | "\(.key)\t\(.value)"
  ' <<<"$json"
}

do_install() {
  [ $# -ge 1 ] || { echo "Missing host arg for --install" >&2; usage; }
  local host="$1"; shift
  validate_host "$host"

  local disko_flags=()
  local overrides=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --disk)
        [ $# -ge 3 ] || { echo "--disk needs <name> <device>" >&2; usage; }
        disko_flags+=(--disk "$2" "$3")
        overrides+=("$2=$3")
        shift 3
        ;;
      *) echo "Unknown arg: $1" >&2; usage ;;
    esac
  done

  echo "==> Reading disko config for '${host}'"
  local -A disks
  while IFS=$'\t' read -r name path; do
    [ -n "$name" ] && disks["$name"]="$path"
  done < <(read_disks "$host" "${overrides[@]}")

  [ ${#disks[@]} -gt 0 ] || { echo "ERROR: no disks found for '${host}'" >&2; exit 1; }

  for name in "${!disks[@]}"; do
    local path="${disks[$name]}"
    if [ ! -e "$path" ]; then
      echo "ERROR: disk '${name}' path '${path}' does not exist." >&2
      echo "Pass --disk ${name} /dev/disk/by-id/... to override." >&2
      exit 1
    fi
  done

  echo
  echo "About to WIPE and install NixOS '${host}' onto:"
  for name in "${!disks[@]}"; do
    local path="${disks[$name]}"
    echo "  ${name}: ${path} -> $(readlink -f "$path")"
  done
  echo
  read -r -p "Type 'WIPE' to continue: " confirm
  [ "$confirm" = "WIPE" ] || { echo "Aborted."; exit 1; }

  if [ ! -s /tmp/disk-password ]; then
    echo
    echo "Enter LUKS passphrase (used for all disks):"
    read -r -s pass1
    echo
    echo "Confirm passphrase:"
    read -r -s pass2
    echo
    [ "$pass1" = "$pass2" ] || { echo "Passphrases do not match."; exit 1; }
    printf '%s' "$pass1" | sudo tee /tmp/disk-password >/dev/null
    sudo chmod 600 /tmp/disk-password
    unset pass1 pass2
  fi

  echo
  echo "==> Closing stale LUKS mappings and unmounting /mnt"
  # Leftover LUKS headers that open with the same passphrase can trick disko
  # into skipping luksFormat and mkfs.btrfs, landing in a half-formatted state.
  # blkdiscard below guarantees every sector is gone.
  for m in cryptroot crypthome; do
    if [ -e "/dev/mapper/$m" ]; then
      sudo cryptsetup close "$m" || true
    fi
  done
  sudo umount -R /mnt 2>/dev/null || true

  echo "==> blkdiscarding each disk"
  for name in "${!disks[@]}"; do
    local real
    real="$(readlink -f "${disks[$name]}")"
    echo "  blkdiscard ${real}"
    sudo blkdiscard -f "$real"
  done

  echo
  echo "==> Phase 1: disko (destroy, format, mount)"
  sudo "${nix_cmd[@]}" run github:nix-community/disko -- \
    --mode destroy,format,mount \
    --root-mountpoint /mnt \
    --yes-wipe-all-disks \
    --flake ".#${host}" \
    "${disko_flags[@]}"

  echo
  echo "==> Verifying mounts"
  local mnt_fstype boot_fstype home_fstype
  mnt_fstype="$(findmnt -n -o FSTYPE /mnt || true)"
  if [ "$mnt_fstype" != "btrfs" ]; then
    echo "ERROR: /mnt is not btrfs (got '${mnt_fstype}'). Disko mount failed." >&2
    mount | grep -E 'mnt|crypt' || true
    exit 1
  fi
  boot_fstype="$(findmnt -n -o FSTYPE /mnt/boot || true)"
  if [ "$boot_fstype" != "vfat" ]; then
    echo "ERROR: /mnt/boot is not vfat (got '${boot_fstype}'). ESP was not mounted." >&2
    exit 1
  fi
  home_fstype="$(findmnt -n -o FSTYPE /mnt/home || true)"
  if [ "$home_fstype" != "btrfs" ]; then
    echo "ERROR: /mnt/home is not btrfs (got '${home_fstype}'). /home was not mounted." >&2
    exit 1
  fi

  echo "  /     (btrfs): $(df -h /mnt      | tail -1 | awk '{print $2" total, "$4" free"}')"
  echo "  /home (btrfs): $(df -h /mnt/home | tail -1 | awk '{print $2" total, "$4" free"}')"
  echo "  /boot (vfat):  $(df -h /mnt/boot | tail -1 | awk '{print $2" total, "$4" free"}')"

  echo
  echo "==> Phase 2: nixos-install"
  sudo nixos-install \
    --root /mnt \
    --flake ".#${host}" \
    --no-root-passwd

  echo
  echo "Unmounting and closing LUKS."
  sudo umount -R /mnt || true
  for m in cryptroot crypthome; do
    sudo cryptsetup close "$m" 2>/dev/null || true
  done

  echo
  echo "Install of '${host}' complete. Reboot when ready."
}

do_wipe() {
  [ $# -ge 1 ] || { echo "Missing host arg for --wipe" >&2; usage; }
  local host="$1"; shift
  validate_host "$host"

  local overrides=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --disk)
        [ $# -ge 3 ] || { echo "--disk needs <name> <device>" >&2; usage; }
        overrides+=("$2=$3")
        shift 3
        ;;
      *) echo "Unknown arg: $1" >&2; usage ;;
    esac
  done

  echo "==> Reading disko config for '${host}'"
  local -A disks
  while IFS=$'\t' read -r name path; do
    [ -n "$name" ] && disks["$name"]="$path"
  done < <(read_disks "$host" "${overrides[@]}")

  [ ${#disks[@]} -gt 0 ] || { echo "ERROR: no disks found for '${host}'" >&2; exit 1; }

  local real_paths=()
  echo
  echo "About to WIPE disks for host '${host}':"
  for name in "${!disks[@]}"; do
    local path="${disks[$name]}"
    if [ ! -e "$path" ]; then
      echo "ERROR: disk '${name}' path '${path}' does not exist." >&2
      exit 1
    fi
    local real
    real="$(readlink -f "$path")"
    real_paths+=("$real")
    echo "  ${name}: ${path} -> ${real}"
  done
  echo
  read -r -p "Type 'WIPE' to continue: " confirm
  [ "$confirm" = "WIPE" ] || { echo "Aborted."; exit 1; }

  echo
  echo "==> Unmounting anything under /mnt"
  sudo umount -R /mnt/target 2>/dev/null || true
  sudo umount -R /mnt/disko-install-root 2>/dev/null || true
  sudo umount -R /mnt 2>/dev/null || true

  echo "==> Closing open LUKS mappings"
  for m in cryptroot crypthome; do
    if [ -e "/dev/mapper/$m" ]; then
      sudo cryptsetup close "$m" || true
    fi
  done

  echo "==> Removing leftover device-mapper entries"
  sudo dmsetup remove_all 2>/dev/null || true

  echo "==> Wiping filesystem signatures"
  sudo wipefs -a "${real_paths[@]}"

  echo "==> Zapping partition tables"
  for real in "${real_paths[@]}"; do
    sudo sgdisk --zap-all "$real"
  done

  echo "==> Re-reading partition tables"
  sudo partprobe "${real_paths[@]}" 2>/dev/null || true

  echo "==> Removing stale LUKS password file"
  sudo rm -f /tmp/disk-password

  echo
  echo "Done. Disks are clean. Run '$0 --install ${host}' to install."
}

[ $# -ge 1 ] || usage

action="$1"; shift

case "$action" in
  --install) do_install "$@"; exit 0 ;;
  --wipe)    do_wipe    "$@"; exit 0 ;;
  --iso|--build|--switch|--boot|--test|--dry) ;;
  *) echo "Unknown action: $action" >&2; usage ;;
esac

# Collect hosts from remaining args
targets=()
for arg in "$@"; do
  validate_host "$arg"
  targets+=("$arg")
done

# Default host selection
if [ ${#targets[@]} -eq 0 ]; then
  case "$action" in
    --iso|--dry)
      targets=("${hosts[@]}")
      ;;
    *)
      targets=("$(current_host)")
      ;;
  esac
fi

for host in "${targets[@]}"; do
  case "$action" in
    --iso)
      echo "Building ${host}-iso..."
      "${inhibit[@]}" "${nix_cmd[@]}" build \
        ".#nixosConfigurations.${host}-iso.config.system.build.isoImage" \
        -o "result-${host}"
      echo "Done: result-${host}/"
      ;;
    --build)
      echo "Building ${host} toplevel..."
      "${inhibit[@]}" "${nix_cmd[@]}" build \
        ".#nixosConfigurations.${host}.config.system.build.toplevel"
      echo "Done: ./result"
      ;;
    --switch)
      echo "Switching ${host}..."
      "${inhibit[@]}" sudo nixos-rebuild switch --flake ".#${host}"
      ;;
    --boot)
      echo "Setting ${host} for next boot..."
      "${inhibit[@]}" sudo nixos-rebuild boot --flake ".#${host}"
      ;;
    --test)
      echo "Testing ${host} (activate without boot entry)..."
      "${inhibit[@]}" sudo nixos-rebuild test --flake ".#${host}"
      ;;
    --dry)
      echo "Dry-run evaluating ${host}..."
      "${inhibit[@]}" "${nix_cmd[@]}" build \
        ".#nixosConfigurations.${host}.config.system.build.toplevel" \
        --dry-run
      echo "OK: ${host}"
      ;;
  esac
done
