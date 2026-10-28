#!/usr/bin/env bash
set -uo pipefail

mac="80:C3:BA:62:0F:62"
name="MOMENTUM 4"
path="/org/bluez/hci0/dev_${mac//:/_}"
a2dp_sink="0000110b-0000-1000-8000-00805f9b34fb"

note() { notify-send -a headphones "$name" "$1" 2>/dev/null || hyprctl notify 1 4000 0 "$name: $1" >/dev/null 2>&1 || true; }

connected() {
  busctl get-property org.bluez "$path" org.bluez.Device1 Connected 2>/dev/null | grep -q true
}

connect() {
  local err=""
  for _ in 1 2 3; do
    if err=$(busctl --timeout=20 call org.bluez "$path" org.bluez.Device1 ConnectProfile s "$a2dp_sink" 2>&1); then
      return 0
    fi
    connected && return 0
    case "$err" in
      *InProgress*|*busy*) sleep 3 ;;
      *) break ;;
    esac
  done
  echo "$err"
  return 1
}

case "${1:-toggle}" in
  status)
    if connected; then echo "connected"; else echo "disconnected"; fi
    exit 0
    ;;
  connect) want=connect ;;
  disconnect) want=disconnect ;;
  toggle) if connected; then want=disconnect; else want=connect; fi ;;
  *) echo "usage: $0 [toggle|connect|disconnect|status]" >&2; exit 1 ;;
esac

if [ "$want" = disconnect ]; then
  if busctl call org.bluez "$path" org.bluez.Device1 Disconnect >/dev/null 2>&1; then
    note "released — the slot is free for another device"
  else
    note "could not disconnect"
  fi
  exit 0
fi

connected && { note "already connected here"; exit 0; }

if err=$(connect); then
  note "connected"
  exit 0
fi

case "$err" in
  *page-timeout*|*host-down*|*HostDown*)
    note "not reachable — are they switched on and in range?" ;;
  *)
    note "refused — both slots are probably taken (phone + Mac). Disconnect them on one of those, then press again." ;;
esac
echo "$err" >&2
exit 1
