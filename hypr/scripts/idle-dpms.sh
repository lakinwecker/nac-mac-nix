#!/usr/bin/env bash
set -uo pipefail

# Blank/unblank the panels for hypridle's idle listener.
#
#   usage: idle-dpms.sh on|off
#
# Why this is a script rather than inline in hypridle.conf:
#
# Under a Lua config `hyprctl dispatch` parses its argument as Lua, so the old
# `hyprctl dispatch dpms off` dies with "')' expected near 'off'" and the whole
# listener silently does nothing. The working spelling is a Lua expression,
# `hl.dsp.dpms("off")`, which has to be quoted inside the `sh -c '...'` that
# hypridle would otherwise need to chain the wayle call — three levels of
# nested quoting. One script instead, so there is a single place to get right.
#
# Not `set -e`: on-resume must reach the dpms call even if wayle is dead,
# otherwise a failed panel call leaves the screens dark with no way back.

case "${1:-}" in
  off)
    wayle panel hide || true
    hyprctl dispatch 'hl.dsp.dpms("off")'
    ;;
  on)
    # dpms first — getting the screens lit matters more than the bar.
    hyprctl dispatch 'hl.dsp.dpms("on")'
    wayle panel show || true
    ;;
  *)
    echo "usage: $0 on|off" >&2
    exit 1
    ;;
esac
