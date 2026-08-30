#!/usr/bin/env bash
set -euo pipefail

# Start/stop lan-mouse, and reclaim the portal file descriptors it leaks.
#
# xdg-desktop-portal-hyprland leaks an EIS fd per input-capture session and
# lan-mouse opens one per barrier crossing, so after roughly 36 crossings the
# D-Bus *session bus* runs out of in-flight fd references and
# xdg-desktop-portal segfaults, taking every client on that bus with it —
# terminals, the bar, Electron apps. Upstream issue:
#   https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419
#   fix in flight: PR #421 (unmerged, part 2 of 3)
#
# Measured on trunkie: +3 fds per crossing, never released. Stopping lan-mouse
# does NOT give them back — the fds belong to xdph and survive until it
# restarts (28 fds still held with lan-mouse fully stopped). So stopping also
# restarts xdph, which is what actually resets the budget (30 -> 5 measured).
#
# Restarting xdph interrupts any in-progress screencast. That is why this is a
# deliberate keybind rather than a background timer.

note() { notify-send -a lan-mouse "lan-mouse" "$1" 2>/dev/null || hyprctl notify 1 3000 0 "$1" >/dev/null 2>&1 || true; }

# Count since the *current* xdph started, not since boot: the budget is per
# portal lifetime, so a since-boot count overstates risk right after a reset.
sessions() {
  local since
  since=$(systemctl --user show -p ActiveEnterTimestamp --value xdg-desktop-portal-hyprland 2>/dev/null || true)
  if [ -n "$since" ]; then
    journalctl --user --since "$since" --no-pager 2>/dev/null | grep -c 'input-capture] New session' || echo 0
  else
    journalctl --user -b --no-pager 2>/dev/null | grep -c 'input-capture] New session' || echo 0
  fi
}

portal_fds() {
  local pid
  pid=$(systemctl --user show -p MainPID --value xdg-desktop-portal-hyprland 2>/dev/null || echo 0)
  [ "${pid:-0}" -gt 0 ] 2>/dev/null || { echo 0; return; }
  ls /proc/"$pid"/fd 2>/dev/null | wc -l
}

case "${1:-toggle}" in
  status)
    printf 'lan-mouse:  %s\nsessions:   %s since the portal started (crashes seen at 39 and 45)\nxdph fds:   %s\n' \
      "$(systemctl --user is-active lan-mouse)" "$(sessions)" "$(portal_fds)"
    exit 0
    ;;
  toggle) ;;
  *) echo "usage: $0 [toggle|status]" >&2; exit 1 ;;
esac

if systemctl --user is-active --quiet lan-mouse; then
  systemctl --user stop lan-mouse
  # Reclaim the leaked descriptors; lan-mouse reconnects fine on next start.
  systemctl --user restart xdg-desktop-portal-hyprland
  note "stopped — portal restarted, fd budget reset"
else
  systemctl --user start lan-mouse
  note "started — $(sessions) portal sessions used this boot"
fi
