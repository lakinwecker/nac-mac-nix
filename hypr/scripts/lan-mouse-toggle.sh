#!/usr/bin/env bash
set -euo pipefail

# Start/stop lan-mouse, and reclaim the portal fds it leaks. xdph leaks ~3 fds
# per barrier crossing and segfaults the whole session bus around 40; only
# restarting xdph reclaims them, so stopping lan-mouse restarts it too.
# https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/419

note() { notify-send -a lan-mouse "lan-mouse" "$1" 2>/dev/null || hyprctl notify 1 3000 0 "$1" >/dev/null 2>&1 || true; }

# Count since the current xdph started: the fd budget is per portal lifetime.
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
  systemctl --user restart xdg-desktop-portal-hyprland
  note "stopped — portal restarted, fd budget reset"
else
  systemctl --user start lan-mouse
  note "started — $(sessions) portal sessions used this boot"
fi
