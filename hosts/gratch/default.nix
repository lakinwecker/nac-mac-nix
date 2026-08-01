# AMD laptop — hostname "gratch"
{ lib, pkgs, username, ... }:
{
  imports = [ ./mt7922-firmware.nix ];  # pin MT7922 wifi firmware (mt76#987 idle-disconnect)

  hardware.amdgpu.initrd.enable = true;

  # Cap Nix build parallelism. Defaults (max-jobs=auto=16 × cores=16) massively
  # oversubscribe the 16 threads and freeze the desktop. 3 jobs × 4 threads =
  # 12 threads, leaving 4 for Hyprland. (60 GB RAM, so memory isn't the limit.)
  nix.settings.max-jobs = 3;
  nix.settings.cores = 4;

  # ── Kernel power params ────────────────────────────────────────────
  boot.kernelParams = [
    "amd_pstate=active"
  ];

  # ── Power management ───────────────────────────────────────────────
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # CPU
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_AC = "performance";
      CPU_BOOST_ON_BAT = 0;
      CPU_BOOST_ON_AC = 1;

      # Runtime PM
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_AC = "on";

      # USB
      USB_AUTOSUSPEND = 1;

      # Wifi
      WIFI_PWR_ON_BAT = "on";
      WIFI_PWR_ON_AC = "off";

      # PCIe
      PCIE_ASPM_ON_BAT = "powersupersave";
      PCIE_ASPM_ON_AC = "default";

      # SATA
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
      SATA_LINKPWR_ON_AC = "max_performance";

      # Audio codec power save
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # Misc
      NMI_WATCHDOG = 0;
      WOL_DISABLE = "Y";
    };
  };

  # (e2fsprogs, ddrescue, etc. now come from ../tools, installed everywhere.)
  environment.systemPackages = with pkgs; [ powertop lm_sensors ];

  # ── secretspec: default to the pass provider ───────────────────────
  # Make bare `pass` use the real store (what lwpass points at).
  environment.sessionVariables.PASSWORD_STORE_DIR = "/home/${username}/passwords/pass";

  # store_dir: the real store is ~/passwords/pass, not ~/.password-store.
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

  # ── Syncthing: only run on AC power ──────────────────────────────────
  # Remove from auto-start targets — power guard and udev manage it
  systemd.services.syncthing.wantedBy = lib.mkForce [];

  # Start syncthing at boot only if on AC
  systemd.services.syncthing-power-guard = {
    description = "Start syncthing if on AC power";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "syncthing-power-guard" ''
        if cat /sys/class/power_supply/*/online 2>/dev/null | grep -q "^1$"; then
          systemctl start syncthing.service 2>/dev/null || true
        fi
      '';
    };
  };

  # Start/stop syncthing on AC plug/unplug
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl stop syncthing.service"
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start syncthing.service"
  '';

  # ── Ollama: don't auto-start (use systemctl start ollama manually) ─
  systemd.services.ollama.wantedBy = lib.mkForce [];

  # ── Display: 120Hz on AC, 60Hz on battery ──────────────────────────
  environment.etc."hypr/scripts/power-refresh.sh" = {
    text = ''
      #!/usr/bin/env bash
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
          hyprctl keyword monitor eDP-1,2560x1600@120,auto,1.25
        else
          hyprctl keyword monitor eDP-1,2560x1600@60,auto,1.25
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
