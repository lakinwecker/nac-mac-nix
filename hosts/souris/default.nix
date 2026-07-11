# Dell XPS 13 9370 (2018, 8th-gen Kaby Lake R, Intel UHD 620) — Anita's laptop
{ pkgs, lib, ... }:
{
  # Anita's own package list lives in a friendly, top-level file
  # (anita-installed-programs.nix, next to machines.nix).
  imports = [ ../../anita-installed-programs.nix ];

  # Default login shell (overrides common's nushell).
  users.defaultUserShell = lib.mkForce pkgs.fish;

  # Secondary admin account for remote maintenance (Lakin). SSH is key-only
  # (see common/networking.nix); sudo uses the initial password below.
  users.users.lakin = {
    isNormalUser = true;
    description = "Lakin";
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsOUCxG23HTAUPwpH03MyXRhrio7J6yUj6gID3fd9dl lakin@sebbers"
    ];
  };

  # Strip personal-infra services that ship in common but don't belong here.
  # (nebula + syncthing are intentionally kept.)
  services.mpd.enable = lib.mkForce false;                    # music daemon
  systemd.user.services.lan-mouse.enable = lib.mkForce false; # desktop KVM

  # Cap Nix build parallelism so it doesn't pin this quad-core (i5/i7-8xxxU):
  # one derivation at a time, up to 4 threads each. Lives in the host module,
  # so it applies to BOTH the souris installer ISO (install-time builds) and
  # the installed system (update-system rebuilds).
  nix.settings.max-jobs = 1;
  nix.settings.cores = 4;

  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Disable the touchscreen (Anita doesn't want it). libinput ignores any
  # device tagged as a touchscreen; touchpad and pen are unaffected.
  services.udev.extraRules = ''
    ACTION=="add|change", ENV{ID_INPUT_TOUCHSCREEN}=="1", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';

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
