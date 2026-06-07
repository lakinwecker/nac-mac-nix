#!/usr/bin/env bash
set -euo pipefail

DELAY="${1:-3}"

REGION=$(slurp)

notify-send "Screenshot" "Capturing in ${DELAY}s…" -t $((DELAY * 1000))
sleep "$DELAY"

grim -g "$REGION" - | wl-copy
notify-send "Screenshot" "Copied to clipboard"
