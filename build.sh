#!/usr/bin/env bash
set -euo pipefail

hosts=($(nix eval --raw --extra-experimental-features nix-command \
  --file machines.nix --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)'))
nix_cmd=(nix --extra-experimental-features 'nix-command flakes')

usage() {
  cat >&2 <<EOF
Usage: $0 <action> [host...]

Actions:
  --iso       Build installer ISO(s)           (output: result-<host>/)
  --build     Build system toplevel (no switch)
  --switch    Build and switch (nixos-rebuild switch)
  --boot      Build and activate on next boot  (nixos-rebuild boot)
  --test      Build and activate now, no boot entry (nixos-rebuild test)
  --dry       Dry-run build (evaluation only)

Hosts: ${hosts[*]}
  If no host is given, defaults to all hosts for --iso/--dry,
  or the current hostname for --switch/--boot/--test/--build.

Examples:
  $0 --switch              # switch this machine
  $0 --iso roach           # build roach ISO
  $0 --iso                 # build all ISOs
  $0 --dry harry sebbers   # dry-run evaluate harry and sebbers
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
  echo "Specify a host explicitly: $0 $action <host>" >&2
  exit 1
}

[ $# -ge 1 ] || usage

action="$1"; shift

case "$action" in
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
      "${nix_cmd[@]}" build \
        ".#nixosConfigurations.${host}-iso.config.system.build.isoImage" \
        -o "result-${host}"
      echo "Done: result-${host}/"
      ;;
    --build)
      echo "Building ${host} toplevel..."
      "${nix_cmd[@]}" build \
        ".#nixosConfigurations.${host}.config.system.build.toplevel"
      echo "Done: ./result"
      ;;
    --switch)
      echo "Switching ${host}..."
      sudo nixos-rebuild switch --flake ".#${host}"
      ;;
    --boot)
      echo "Setting ${host} for next boot..."
      sudo nixos-rebuild boot --flake ".#${host}"
      ;;
    --test)
      echo "Testing ${host} (activate without boot entry)..."
      sudo nixos-rebuild test --flake ".#${host}"
      ;;
    --dry)
      echo "Dry-run evaluating ${host}..."
      "${nix_cmd[@]}" build \
        ".#nixosConfigurations.${host}.config.system.build.toplevel" \
        --dry-run
      echo "OK: ${host}"
      ;;
  esac
done
