#!/usr/bin/env bash
set -euo pipefail

# Toggle a KVM-shared monitor and re-establish lan-mouse's pointer barrier.
#
# xdg-desktop-portal-hyprland only accepts barriers on the exterior boundary of
# the output layout, and lan-mouse only requests barriers at session start — so
# changing the layout requires a lan-mouse restart or crossing stops working.

unset LD_LIBRARY_PATH

. /etc/hypr/scripts/hypr-lua.sh

usage() { echo "usage: $0 on|off <output>" >&2; exit 1; }

[ $# -eq 2 ] || usage
action=$1
output=$2

case "$action" in
  off)
    hypr_monitor "{ output = \"$output\", disabled = true }"
    ;;
  on)
    # Re-apply from hyprland.lua so the geometry has one source of truth.
    hyprctl reload
    ;;
  *)
    usage
    ;;
esac

# Let Hyprland finish reflowing before lan-mouse asks for zones again.
sleep 1

if systemctl --user cat lan-mouse.service >/dev/null 2>&1; then
  systemctl --user restart lan-mouse
fi
