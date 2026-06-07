{ pkgs, username, ... }:
{
  # ── Bluetooth ───────────────────────────────────────────────────────
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
  services.upower.enable = true;

  # Bluetooth audio — WirePlumber 0.5+ uses JSON config, not Lua
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

  # ── PipeWire ────────────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ── Music (MPD) ────────────────────────────────────────────────────
  services.mpd = {
    enable = true;
    user = username;
    settings.music_directory = "/home/${username}/music";
    settings.audio_output = [{
      type = "pipewire";
      name = "PipeWire Output";
    }];
  };
  systemd.services.mpd.environment = {
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
}
