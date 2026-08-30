{ pkgs, lib, ... }:
let
  # Bluetooth devices we always trust. An untrusted device makes bluez ask the
  # desktop agent to authorize every service profile it opens — Handsfree,
  # A/V Remote Control, Audio Sink — so a headset costs three prompts on every
  # single connect. Trusting the device auto-authorizes all of them.
  #
  # bluez already persists this in /var/lib/bluetooth once set by hand; the
  # service below exists so it survives a fresh install and is declared rather
  # than remembered. MACs that aren't paired on a given host are skipped.
  trustedDevices = {
    "MOMENTUM 4" = "80:C3:BA:62:0F:62";
    "MX Master 3S" = "DE:6A:6A:F8:14:82";
  };
in
{
  # ── Adapter ─────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        FastConnectable = true;
        Experimental = true;   # enables battery reporting & LE features
      };
      Policy = {
        AutoEnable = true;
        ReconnectAttempts = 7;
        ReconnectIntervals = "1,2,4,8,16,32,64";
      };
    };
  };

  # ── Trusted devices ─────────────────────────────────────────────────
  # Re-run by hand after pairing something new: it only picks up devices that
  # already exist on the bus, so a device paired post-boot waits for the next
  # start unless you `systemctl restart bluetooth-trust-devices`.
  systemd.services.bluetooth-trust-devices = {
    description = "Mark known Bluetooth devices as trusted";
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    wantedBy = [ "bluetooth.target" ];
    path = [ pkgs.systemd pkgs.coreutils pkgs.gnugrep ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # bluetoothd takes the bus name before it finishes exporting the device
      # objects we're about to poke, so wait for the tree to answer.
      for _ in $(seq 30); do
        busctl tree org.bluez --list > /dev/null 2>&1 && break
        sleep 1
      done

      trust() {
        mac="$1"; label="$2"
        node="dev_$(echo "$mac" | tr 'a-f:' 'A-F_')"
        # Trust is stored per-adapter, and trunkie has two radios, so set it on
        # every controller this device is paired with.
        paths=$(busctl tree org.bluez --list 2>/dev/null | grep -E "/$node$" || true)
        if [ -z "$paths" ]; then
          echo "$label ($mac) not paired on this host — skipping"
          return 0
        fi
        for path in $paths; do
          busctl set-property org.bluez "$path" org.bluez.Device1 Trusted b true \
            && echo "trusted $label at $path"
        done
      }

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList
        (label: mac: "trust ${lib.escapeShellArg mac} ${lib.escapeShellArg label}")
        trustedDevices)}
    '';
  };

  # ── Audio backend ───────────────────────────────────────────────────
  # bluez side of PipeWire; the rest of the audio stack lives in audio.nix.
  # WirePlumber 0.5+ uses JSON config, not Lua.
  environment.etc."wireplumber/wireplumber.conf.d/51-bluez.conf".text = ''
    monitor.bluez.properties = {
      bluez5.enable-sbc-xq = true
      bluez5.enable-msbc = true
      bluez5.enable-hw-volume = true
      bluez5.headset-roles = [ hsp_hs hsp_ag hfp_hg hfp_ag ]
      bluez5.auto-connect = [ hfp_hg a2dp_sink ]
    }

    monitor.bluez.rules = [
      {
        matches = [ { node.name = "~bluez_output.*" } ]
        actions = {
          update-props = {
            session.suspend-timeout-seconds = 0
          }
        }
      }
    ]
  '';
}
