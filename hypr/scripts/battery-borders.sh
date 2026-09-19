#!/usr/bin/env bash
# Scales window borders by remaining battery once below a threshold.
set -euo pipefail

. /etc/hypr/scripts/hypr-lua.sh

DEFAULT_SIZE=2
DEFAULT_ACTIVE=0xffd7827e
DEFAULT_INACTIVE=0xff286983

LOW_THRESHOLD=20
LOW_COLOR=0xffd7827e
CRITICAL_THRESHOLD=10
CRITICAL_COLOR=0xffff0000
LOW_START_SIZE=5
LOW_GROWTH_DIV=8

POLL_INTERVAL=5

bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1 || true)
if [ -z "$bat" ]; then
    exit 0
fi

# `|| true` because of `set -e`: hypr_config returns non-zero on a failed
# hyprctl call, which would otherwise end the poll loop for the session.
set_borders() {
    local size=$1 active=$2 inactive=$3
    hypr_config "{ general = { border_size = $size, col = { active_border = \"$active\", inactive_border = \"$inactive\" } } }" || true
}

while true; do
    capacity=$(cat "$bat/capacity" 2>/dev/null || echo 100)
    status=$(cat "$bat/status" 2>/dev/null || echo Unknown)

    if [ "$status" = "Charging" ] || [ "$status" = "Full" ] || [ "$capacity" -gt "$LOW_THRESHOLD" ]; then
        set_borders "$DEFAULT_SIZE" "$DEFAULT_ACTIVE" "$DEFAULT_INACTIVE"
    else
        delta=$(( LOW_THRESHOLD - capacity ))
        size=$(( LOW_START_SIZE + delta * delta * delta / LOW_GROWTH_DIV ))
        if [ "$capacity" -le "$CRITICAL_THRESHOLD" ]; then
            color=$CRITICAL_COLOR
        else
            color=$LOW_COLOR
        fi
        set_borders "$size" "$color" "$color"
    fi

    sleep "$POLL_INTERVAL"
done
