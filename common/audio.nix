{ username, ... }:
{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

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
