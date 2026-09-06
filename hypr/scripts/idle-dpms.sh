#!/usr/bin/env bash
set -uo pipefail

# Blank/unblank the screens for hypridle's idle listener.
#
#   usage: idle-dpms.sh on|off
#
# Why this is a script rather than inline in hypridle.conf:
#
# Under a Lua config `hyprctl dispatch` parses its argument as Lua, so the old
# `hyprctl dispatch dpms off` dies with "')' expected near 'off'" and the whole
# listener silently does nothing. The working spelling is a Lua expression,
# `hl.dsp.dpms("off")`, whose quotes and parens do not survive the `sh -c` that
# hypridle wraps every command in. One script instead, so the quoting lives in
# exactly one place.
#
# This deliberately does NOT touch the Wayle bar. Hiding it bought nothing --
# the screens are off, nobody can see the bar, and Wayle sits on layer "top"
# so hyprlock (layer "overlay") already covers it -- while `wayle panel show`
# on resume was unreliable enough to leave the bar gone until a manual
# `wayle panel restart`.

case "${1:-}" in
  off)
    hyprctl dispatch 'hl.dsp.dpms("off")'
    ;;
  on)
    hyprctl dispatch 'hl.dsp.dpms("on")'
    ;;
  *)
    echo "usage: $0 on|off" >&2
    exit 1
    ;;
esac
