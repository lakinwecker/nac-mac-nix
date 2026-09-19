#!/usr/bin/env bash
set -uo pipefail

# A script, not inline in hypridle.conf: the Lua dispatch expression's quotes
# do not survive the `sh -c` hypridle wraps every command in.

. /etc/hypr/scripts/hypr-lua.sh

case "${1:-}" in
  off)
    hypr_dispatch 'hl.dsp.dpms("off")'
    ;;
  on)
    hypr_dispatch 'hl.dsp.dpms("on")'
    ;;
  *)
    echo "usage: $0 on|off" >&2
    exit 1
    ;;
esac
