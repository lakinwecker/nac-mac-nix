#!/usr/bin/env bash
# The one place that knows how to talk to a Lua-config Hyprland.
# Source it: `. /etc/hypr/scripts/hypr-lua.sh`
#
# Two hyprlang-era spellings still look right but fail silently:
#
#   hyprctl keyword <key> <val>   -> "can't work with non-legacy parsers", exit 0
#   hyprctl dispatch <hyprlang>   -> argument is parsed as Lua now, exit 7
#
# Hence: no keyword wrapper at all, and every call checks the output for an
# error line rather than trusting the exit code. hypr/lint-hyprctl.sh keeps
# the old forms from creeping back.
#
# Key names nest: `general:col.active_border` is
# `{ general = { col = { active_border = ... } } }` (':' -> '.', '-' -> '_').
# Dispatchers are snake_case under hl.dsp — `sendshortcut` is
# `hl.dsp.send_shortcut`. Full list: the Hyprland package's
# share/hypr/stubs/hl.meta.lua. A wrong argument shape errors with the
# expected table, e.g. "send_shortcut: expected a table { mods, key, window? }".

_hypr_run() {
    local verb=$1 expr=$2 out rc
    out=$(hyprctl "$verb" "$expr" 2>&1)
    rc=$?
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -qi '^error:'; then
        printf 'hypr-lua: %s failed: %s\n  expr: %s\n' "$verb" "$out" "$expr" >&2
        return 1
    fi
}

# hypr_dispatch 'hl.dsp.dpms("off")'
hypr_dispatch() { _hypr_run dispatch "$1"; }

# hypr_config '{ general = { border_size = 4 } }'  -- replaces `hyprctl keyword`
hypr_config() { _hypr_run eval "hl.config($1)"; }

# hypr_monitor '{ output = "eDP-1", mode = "2560x1600@120", scale = 1.25 }'
hypr_monitor() { _hypr_run eval "hl.monitor($1)"; }

# Escape hatch for anything the above do not cover.
hypr_eval() { _hypr_run eval "$1"; }
