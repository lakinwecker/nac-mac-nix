{ pkgs, username, ... }:
{
  # ── Nix settings ────────────────────────────────────────────────────
  nixpkgs.hostPlatform = "x86_64-linux";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Trust wheel users for Nix (extra substituters, remote builders, --option,
  # nix copy, …). Merges with Nix's own "root" entry.
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;

  # ── Shell ───────────────────────────────────────────────────────────
  # Normal priority (beats the bash module's mkDefault). Per-host overrides
  # (e.g. souris → fish) must use lib.mkForce.
  users.defaultUserShell = pkgs.nushell;
  programs.bash.enable = true;
  programs.fish = {
    enable = true;
    # Registers fish in /etc/shells so it can be a login shell.
  };
  # programs.nushell is a home-manager option, not a NixOS one.
  # Register nushell in /etc/shells so it can be a login shell.
  environment.shells = [ pkgs.nushell ];

  # ── Locale / time ──────────────────────────────────────────────────
  time.timeZone = "America/Edmonton";
  time.hardwareClockInLocalTime = true;

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
