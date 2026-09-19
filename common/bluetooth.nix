{ pkgs, lib, ... }:
let
  # Trusted devices skip per-profile authorization prompts on every connect.
  trustedDevices = {
    "MOMENTUM 4" = "80:C3:BA:62:0F:62";
    "MX Master 3S" = "DE:6A:6A:F8:14:82";
  };
in
{
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

  # Only trusts devices already on the bus; restart after pairing something new.
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
      # bluetoothd owns the bus name before it exports device objects.
      for _ in $(seq 30); do
        busctl tree org.bluez --list > /dev/null 2>&1 && break
        sleep 1
      done

      trust() {
        mac="$1"; label="$2"
        node="dev_$(echo "$mac" | tr 'a-f:' 'A-F_')"
        # Trust is per-adapter; trunkie has two radios.
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
