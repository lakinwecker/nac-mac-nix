# Dell XPS 13 9370 (2018, 8th-gen Kaby Lake R, Intel UHD 620) — Anita's laptop
{ pkgs, lib, ... }:
{
  # Anita's own package list lives in a friendly, top-level file
  # (anita-installed-programs.nix, next to machines.nix).
  imports = [ ../../anita-installed-programs.nix ];

  # Default login shell (overrides common's nushell).
  users.defaultUserShell = lib.mkForce pkgs.fish;

  # Strip personal-infra services that ship in common but don't belong here.
  # (nebula + syncthing are intentionally kept.)
  services.mpd.enable = lib.mkForce false;                    # music daemon
  systemd.user.services.lan-mouse.enable = lib.mkForce false; # desktop KVM

  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

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
    };
  };
  services.thermald.enable = true;

  # `update-system` — the one command Anita runs after editing
  # anita-installed-programs.nix. Rebuilds souris from the config repo.
  environment.systemPackages = with pkgs; [
    powertop
    lm_sensors
    (writeShellScriptBin "update-system" ''
      set -euo pipefail
      # Where this config repo is checked out on souris. If you clone it
      # somewhere else, change this line (or set NIXOS_CONFIG_DIR).
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
