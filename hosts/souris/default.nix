# Dell XPS 13 9370 (Kaby Lake R, Intel UHD 620) — Anita's laptop
{ pkgs, lib, ... }:
{
  imports = [ ../../anita-installed-programs.nix ];

  programs.fish.enable = true;
  users.defaultUserShell = lib.mkForce pkgs.fish;

  # Secondary admin account for remote maintenance.
  users.users.lakin = {
    isNormalUser = true;
    description = "Lakin";
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsOUCxG23HTAUPwpH03MyXRhrio7J6yUj6gID3fd9dl lakin@sebbers"
    ];
  };

  # Strip personal-infra services from common; nebula + syncthing stay.
  services.mpd.enable = lib.mkForce false;
  systemd.user.services.lan-mouse.enable = lib.mkForce false;

  # Don't pin this quad-core. Applies to the ISO and the installed system both.
  nix.settings.max-jobs = 1;
  nix.settings.cores = 4;

  # Only 8 GB and no disk swap, so zram is the only swap.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };
  boot.kernel.sysctl."vm.swappiness" = 150;

  # Let earlyoom (common/default.nix) kill the browser, not her image edits.
  services.earlyoom.extraArgs = [ "--avoid" "^gimp" ];

  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Disable the touchscreen (Anita doesn't want it).
  services.udev.extraRules = ''
    ACTION=="add|change", ENV{ID_INPUT_TOUCHSCREEN}=="1", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';

  # Intel VA-API HW decode; without iHD, Firefox software-decodes.
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
  programs.firefox.preferences = {
    "media.ffmpeg.vaapi.enabled" = true;
    "media.rdd-ffmpeg.enabled" = true;
    "gfx.webrender.all" = true;
  };

  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      # ath10k power-save times out key installs (-110); keep the radio awake.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";
    };
  };
  services.thermald.enable = true;

  # QCA6174/ath10k needs a real regdom; world (0x0) breaks DFS 5GHz throughput.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''options cfg80211 ieee80211_regdom=CA'';

  environment.systemPackages = with pkgs; [
    powertop
    lm_sensors
    libva-utils      # vainfo
    intel-gpu-tools  # intel_gpu_top
    iw               # wifi diagnostics
    pciutils         # lspci
    (writeShellScriptBin "update-system" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_DIR:-$HOME/nac-mac-nix}"
      if [ ! -e "$repo/flake.nix" ]; then
        echo "Couldn't find the config at $repo" >&2
        echo "Set NIXOS_CONFIG_DIR to where it lives and try again." >&2
        exit 1
      fi
      echo "==> Updating the system from $repo ..."
      exec sudo nixos-rebuild switch --flake "$repo#souris"
    '')
  ];
}
