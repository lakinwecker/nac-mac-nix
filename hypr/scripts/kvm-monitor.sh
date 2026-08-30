#!/usr/bin/env bash
set -euo pipefail

# Toggle a KVM-shared monitor and re-establish lan-mouse's pointer barrier.
#
#   usage: kvm-monitor.sh on|off <output>
#
# Why this restarts lan-mouse:
#
# xdg-desktop-portal-hyprland only accepts pointer barriers that sit on the
# *exterior* boundary of the output layout — isVerticalBarrierOnExteriorBoundary
# walks the barrier and rejects any segment with a monitor on both sides. With
# two monitors side by side the shared edge has exactly that, so lan-mouse's
# barrier there is refused ("valid: false") and only the outermost edge works.
#
# Dropping the shared panel makes the remaining monitor's edge exterior, so the
# barrier becomes valid — but lan-mouse only requests barriers when its capture
# session starts. Without a restart it keeps the barrier set it asked for under
# the old layout, and crossing stops working in exactly the mode you switched
# into.

usage() { echo "usage: $0 on|off <output>" >&2; exit 1; }

[ $# -eq 2 ] || usage
action=$1
output=$2

case "$action" in
  off)
    hyprctl eval "hl.monitor({ output = \"$output\", disabled = true })"
    ;;
  on)
    # Re-apply from hyprland.lua rather than repeating the mode here, so the
    # geometry has exactly one source of truth.
    hyprctl reload
    ;;
  *)
    usage
    ;;
esac

# Let Hyprland finish reflowing before lan-mouse asks for zones again.
sleep 1

# Only on hosts that actually run the KVM daemon.
if systemctl --user cat lan-mouse.service >/dev/null 2>&1; then
  systemctl --user restart lan-mouse
fi
