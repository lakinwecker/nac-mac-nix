#!/usr/bin/env bash
# hyprctl wrappers for a Lua-config Hyprland. Source it.
# `hyprctl keyword` exits 0 doing nothing, so there is no keyword wrapper and
# every call greps the output instead of trusting the exit code.
# `hyprctl dispatch` parses its argument as Lua.
# Key names nest and rewrite ':' -> '.', '-' -> '_'; dispatchers are snake_case
# under hl.dsp. Full list: the Hyprland package's share/hypr/stubs/hl.meta.lua.

_hypr_run() {
    local verb=$1 expr=$2 out rc
    out=$(hyprctl "$verb" "$expr" 2>&1)
    rc=$?
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -qi '^error:'; then
        printf 'hypr-lua: %s failed: %s\n  expr: %s\n' "$verb" "$out" "$expr" >&2
        return 1
    fi
}

hypr_dispatch() { _hypr_run dispatch "$1"; }

hypr_config() { _hypr_run eval "hl.config($1)"; }

hypr_monitor() { _hypr_run eval "hl.monitor($1)"; }

hypr_eval() { _hypr_run eval "$1"; }
