#!/usr/bin/env bash
set -euo pipefail

# Bound to XF86PowerOff; logind's HandlePowerKey is "ignore".

# Never offer session actions over the lock screen.
if pidof hyprlock >/dev/null 2>&1; then
  exit 0
fi

entries=("Lock" "Suspend")

# Only offer hibernate where a resume device is actually configured.
if grep -qw disk /sys/power/state 2>/dev/null \
  && [ -r /sys/power/resume ] \
  && [ "$(cat /sys/power/resume)" != "0:0" ]; then
  entries+=("Hibernate")
fi

entries+=("Log out" "Reboot" "Shut down")

choice=$(printf '%s\n' "${entries[@]}" \
  | rofi -dmenu -i -p Power -theme /etc/hypr/rofi-tokyonight.rasi) || exit 0

case "$choice" in
  "Lock")      loginctl lock-session ;;
  "Suspend")   systemctl suspend ;;
  "Hibernate") systemctl hibernate ;;
  "Log out")   hyprctl dispatch exit ;;
  "Reboot")    systemctl reboot ;;
  "Shut down") systemctl poweroff ;;
esac
