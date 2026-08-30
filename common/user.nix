{ pkgs, username, ... }:
{
  # ── Nix settings ────────────────────────────────────────────────────
  nixpkgs.hostPlatform = "x86_64-linux";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Trust wheel users for Nix (extra substituters, remote builders, --option,
  # nix copy, …). Merges with Nix's own "root" entry.
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.substituters = [ "https://cache.nixos.org" "https://hyprland.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];
  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;

  # ── Shell ───────────────────────────────────────────────────────────
  # Normal priority (beats the bash module's mkDefault). Per-host overrides
  # (e.g. souris → fish) must use lib.mkForce.
  users.defaultUserShell = pkgs.nushell;
  programs.bash.enable = true;
  # programs.nushell is a home-manager option, not a NixOS one.
  # Register nushell in /etc/shells so it can be a login shell.
  environment.shells = [ pkgs.nushell ];

  # ── Locale / time ──────────────────────────────────────────────────
  time.timeZone = "America/Edmonton";
  time.hardwareClockInLocalTime = true;

  # ── /home must be mounted before activation ────────────────────────
  # Every host here keeps /home on its own filesystem, and roughly a dozen
  # activation scripts (ghostty, hypr, nvim, nushell, starship, zellij, bin,
  # lan-mouse, …) write into it. On hosts with boot.initrd.systemd.enable,
  # NixOS runs the whole activation script from the initrd — before /home is
  # mounted. Those writes land in the bare mountpoint on the root filesystem
  # and are shadowed the instant /home mounts over them, so home config only
  # ever took effect on `switch`, never on boot. systemd reports the leftovers
  # as "Directory /home to mount over is not empty, mounting anyway."
  #
  # neededForBoot pulls the mount into stage 1, ahead of activation. Note the
  # trade-off: /home failing to mount now drops to emergency instead of
  # booting without it.
  fileSystems."/home".neededForBoot = true;

  # ── Home directory ownership ───────────────────────────────────────
  system.activationScripts.userHomeOwnership = {
    deps = [ "users" "ghosttyConfig" "userBin" ];
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
