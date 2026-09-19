#!/usr/bin/env bash
set -euo pipefail

# Bound to XF86PowerOff; logind's HandlePowerKey is "ignore".
# wlogout, not rofi: rofi has no touch support, so the menu would be
# undismissable on a Surface with the Type Cover detached.

if pidof hyprlock >/dev/null 2>&1; then
  exit 0
fi

# Swallow the power press that woke the machine. /run/last-resume is stamped by
# powerManagement.resumeCommands in hypr/default.nix.
resume_grace=5
if [ -f /run/last-resume ]; then
  since=$(( $(date +%s) - $(stat -c %Y /run/last-resume) ))
  if [ "$since" -ge 0 ] && [ "$since" -lt "$resume_grace" ]; then
    exit 0
  fi
fi

# Hosts that set systemd.targets.<x>.enable = false report "masked".
unit_available() {
  [ "$(systemctl is-enabled "$1" 2>/dev/null)" != "masked" ]
}

# A second press should dismiss, not stack another copy.
if pkill -x wlogout 2>/dev/null; then
  exit 0
fi

layout=$(mktemp -t wlogout-layout.XXXXXX)
trap 'rm -f "$layout"' EXIT

entry() {
  printf '{"label":"%s","action":"%s","text":"%s","keybind":"%s"}\n' "$1" "$2" "$3" "$4"
}

{
  entry lock "loginctl lock-session" "Lock" l

  if unit_available suspend.target; then
    entry suspend "systemctl suspend" "Suspend" u
  fi

  # @hibernate@ is hyprHibernate from machines.nix, substituted at build time.
  if [ "@hibernate@" = "1" ] \
    && unit_available hibernate.target \
    && grep -qw disk /sys/power/state 2>/dev/null \
    && [ -r /sys/power/resume ] \
    && [ "$(cat /sys/power/resume)" != "0:0" ]; then
    entry hibernate "systemctl hibernate" "Hibernate" h
  fi

  # wlogout execs the action through sh, so it can't use hypr-lua.sh's wrappers.
  entry logout   "hyprctl dispatch 'hl.dsp.exit()'" "Log out"  e
  entry reboot   "systemctl reboot"      "Reboot"   r
  entry shutdown "systemctl poweroff"    "Shut down" s

  # The touch escape hatch: wlogout closes on Esc, but Esc needs a keyboard.
  entry cancel "true" "Cancel" c
} > "$layout"

# Not exec'd: exec would skip the EXIT trap and leak the layout file.
wlogout \
  --layout "$layout" \
  --css /etc/hypr/wlogout.css \
  --buttons-per-row 3 \
  --column-spacing 20 \
  --row-spacing 20 \
  --margin 150 \
  --show-binds
