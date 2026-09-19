# AMD laptop
{ lib, pkgs, username, ... }:
{
  imports = [ ./mt7922-firmware.nix ];

  hardware.amdgpu.initrd.enable = true;

  # 3 x 4 of 16 threads; the defaults oversubscribe and freeze the desktop.
  nix.settings.max-jobs = 3;
  nix.settings.cores = 4;

  boot.kernelParams = [
    "amd_pstate=active"
  ];

  powerManagement.enable = true;
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_AC = "performance";
      CPU_BOOST_ON_BAT = 0;
      CPU_BOOST_ON_AC = 1;
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_AC = "on";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_BAT = "on";
      WIFI_PWR_ON_AC = "off";
      PCIE_ASPM_ON_BAT = "powersupersave";
      PCIE_ASPM_ON_AC = "default";
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
      SATA_LINKPWR_ON_AC = "max_performance";
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
      NMI_WATCHDOG = 0;
      WOL_DISABLE = "Y";
    };
  };

  environment.systemPackages = with pkgs; [ powertop lm_sensors ];

  # The real pass store is ~/passwords/pass, not ~/.password-store.
  environment.etc."secretspec/config.toml".text = ''
    [defaults]
    provider = "pass://?store_dir=/home/${username}/passwords/pass"
    profile = "default"
  '';

  system.activationScripts.secretspecConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${username} -g users /home/${username}/.config/secretspec
      ln -sf /etc/secretspec/config.toml /home/${username}/.config/secretspec/config.toml
      chown -h ${username}:users /home/${username}/.config/secretspec/config.toml
    '';
  };

  # Ollama: start manually.
  systemd.services.ollama.wantedBy = lib.mkForce [];

  # 120Hz on AC, 60Hz on battery.
  environment.etc."hypr/scripts/power-refresh.sh" = {
    text = ''
      #!/usr/bin/env bash
      . /etc/hypr/scripts/hypr-lua.sh

      CURRENT_STATE=""

      set_refresh() {
        local state
        if cat /sys/class/power_supply/*/online 2>/dev/null | grep -q "^1$"; then
          state="ac"
        else
          state="bat"
        fi
        [ "$state" = "$CURRENT_STATE" ] && return
        CURRENT_STATE="$state"
        if [ "$state" = "ac" ]; then
          hypr_monitor '{ output = "eDP-1", mode = "2560x1600@120", position = "auto", scale = 1.25 }'
        else
          hypr_monitor '{ output = "eDP-1", mode = "2560x1600@60", position = "auto", scale = 1.25 }'
        fi
      }

      set_refresh
      ${pkgs.upower}/bin/upower --monitor | while read -r _; do
        set_refresh
      done
    '';
    mode = "0755";
  };
}
