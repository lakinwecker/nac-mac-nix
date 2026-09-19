#!/usr/bin/env bash
# Dispatches mac-style shortcuts that need terminal detection.
# Copy/paste are handled directly in hyprland.lua via X11 legacy keys
# (Ctrl+Insert / Shift+Insert) — no detection needed for those.
set -euo pipefail

. /etc/hypr/scripts/hypr-lua.sh

action="${1:-}"
if [ -z "$action" ]; then
  echo "usage: $0 <cut|select-all|undo|redo>" >&2
  exit 1
fi

info=$(hyprctl activewindow -j 2>/dev/null || echo '{}')
class=$(printf '%s' "$info" | jq -r '.class // ""')
initialClass=$(printf '%s' "$info" | jq -r '.initialClass // ""')
title=$(printf '%s' "$info" | jq -r '.title // ""')

is_terminal=0
case "${class},${initialClass},${title}" in
  *ghostty*|*kitty*|*foot*|*alacritty*|*wezterm*|*Terminal*|*terminal*|*xterm*|*zellij*|*tmux*)
    is_terminal=1
    ;;
esac

send() {
  # $1 = modifiers (space-separated), $2 = key
  hypr_dispatch "hl.dsp.send_shortcut({ mods = \"$1\", key = \"$2\", window = \"activewindow\" })"
}

case "$action" in
  cut)
    if [ "$is_terminal" = 1 ]; then send "CTRL SHIFT" "x"; else send "CTRL" "x"; fi
    ;;
  select-all)
    send "CTRL" "a"
    ;;
  undo)
    if [ "$is_terminal" = 1 ]; then send "CTRL SHIFT" "z"; else send "CTRL" "z"; fi
    ;;
  redo)
    send "CTRL SHIFT" "z"
    ;;
  *)
    echo "unknown action: $action" >&2
    exit 2
    ;;
esac
