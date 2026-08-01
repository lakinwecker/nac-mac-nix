#!/usr/bin/env bash
set -euo pipefail

# Usage: screenshot.sh area
#        screenshot.sh delayed [seconds]
MODE="${1:-area}"
DELAY="${2:-3}"

ROUNDING=8   # match hyprland.conf decoration:rounding
QUALITY=90
OUTDIR="$HOME/Pictures/Screenshots"

mkdir -p "$OUTDIR"
OUT="$OUTDIR/$(date +%Y-%m-%d_%H-%M-%S).webp"

capture() {
  case "$MODE" in
    delayed)
      grim -g "$REGION" -
      ;;
    *)
      grimblast save area -
      ;;
  esac
}

# Round the corners into the alpha channel, then encode.
encode() {
  magick png:- \
    \( +clone -alpha extract \
       -draw "fill black polygon 0,0 0,$ROUNDING $ROUNDING,0 fill white circle $ROUNDING,$ROUNDING $ROUNDING,0" \
       \( +clone -flip \) -compose Multiply -composite \
       \( +clone -flop \) -compose Multiply -composite \
    \) -alpha off -compose CopyOpacity -composite png:- \
  | cwebp -q "$QUALITY" -m 6 -alpha_q 100 -quiet -o - -- -
}

if [ "$MODE" = delayed ]; then
  REGION=$(slurp)
  notify-send "Screenshot" "Capturing in ${DELAY}s…" -t $((DELAY * 1000))
  sleep "$DELAY"
fi

capture | encode | tee "$OUT" | wl-copy --type image/webp

notify-send "Screenshot" "$(basename "$OUT") ($(du -bh "$OUT" | cut -f1))"
