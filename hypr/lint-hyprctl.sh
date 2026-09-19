#!/usr/bin/env bash
# Fails if anything still talks to Hyprland the hyprlang way; both banned forms
# fail silently at runtime. See hypr/scripts/hypr-lua.sh.
set -uo pipefail

root=${1:-.}
status=0

mapfile -t files < <(
  find "$root" \
    \( -name .git -o -name result -o -path '*/node_modules' \) -prune -o \
    -type f \( -name '*.nix' -o -name '*.sh' -o -name '*.lua' -o -name '*.conf' -o -name '*.py' \) \
    -print | sort
)

uncommented() { grep -n '' "$1" | grep -vP '^\d+:\s*(#|--)'; }

report() {
  status=1
  while IFS= read -r line; do printf '%s:%s\n    %s\n' "$1" "$line" "$2" >&2; done <<<"$3"
}

for f in "${files[@]}"; do
  [ "$(basename "$f")" = "lint-hyprctl.sh" ] && continue

  if hits=$(uncommented "$f" | grep -P 'hyprctl\s+keyword'); then
    report "$f" "hyprlang-only, exits 0 doing nothing — use hypr_config / hypr_monitor" "$hits"
  fi

  # dispatch must get a Lua expression: an hl. call, or a var holding one.
  if hits=$(uncommented "$f" | grep -P "hyprctl\s+dispatch\s+(?![\"']?(hl\.|\\\$|@))"); then
    report "$f" "argument is parsed as Lua — use an hl.dsp.* expression" "$hits"
  fi
done

[ "$status" -eq 0 ] && echo "hyprctl-lua: clean (${#files[@]} files)"
exit "$status"
