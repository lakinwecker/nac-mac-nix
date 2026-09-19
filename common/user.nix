{ pkgs, username, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.substituters = [ "https://cache.nixos.org" "https://hyprland.cachix.org" "https://devenv.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
  ];
  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;

  # Normal priority, so per-host overrides need lib.mkForce.
  users.defaultUserShell = pkgs.nushell;
  programs.bash.enable = true;
  environment.shells = [ pkgs.nushell ];

  # Real store is the syncthing'd ~/passwords/pass; bare `pass` (backup.sh,
  # non-nushell callers) finds an empty store without this.
  environment.sessionVariables.PASSWORD_STORE_DIR = "/home/${username}/passwords/pass";

  time.timeZone = "America/Edmonton";
  time.hardwareClockInLocalTime = true;

  # Pulls /home into stage 1 so the many activation scripts that write into it
  # aren't shadowed by the later mount. Trade-off: a failed mount now drops to
  # emergency instead of booting without /home.
  fileSystems."/home".neededForBoot = true;

  system.activationScripts.userHomeOwnership = {
    deps = [ "users" "ghosttyConfig" "userBinCleanup" ];
    text = ''
      install -d -o ${username} -g users /home/${username}/.config
      install -d -o ${username} -g users /home/${username}/.local
      install -d -o ${username} -g users /home/${username}/.local/share
      install -d -o ${username} -g users /home/${username}/.local/state
      install -d -o ${username} -g users /home/${username}/.cache
      chown -R ${username}:users \
        /home/${username}/.config \
        /home/${username}/.local \
        /home/${username}/.cache \
        /home/${username}/bin 2>/dev/null || true
    '';
  };
}
