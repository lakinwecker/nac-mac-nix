{ pkgs, ... }:
{
  # ── Nix settings ────────────────────────────────────────────────────
  nixpkgs.hostPlatform = "x86_64-linux";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;

  # ── Shell ───────────────────────────────────────────────────────────
  users.defaultUserShell = pkgs.fish;
  programs.bash.enable = true;
  programs.fish = {
    enable = true;
    # Registers fish in /etc/shells so it can be a login shell.
  };
  # programs.nushell is a home-manager option, not a NixOS one.
  # nushell is installed via environment.systemPackages in packages.nix.

  # ── Locale / time ──────────────────────────────────────────────────
  time.timeZone = "America/Edmonton";
  time.hardwareClockInLocalTime = true;

  # ── Home directory ownership ───────────────────────────────────────
  system.activationScripts.userHomeOwnership = {
    deps = [ "users" "hyprConfig" "ghosttyConfig" "userBin" ];
    text = ''
      install -d -o lakin -g users /home/lakin/.config
      install -d -o lakin -g users /home/lakin/.local
      install -d -o lakin -g users /home/lakin/.local/share
      install -d -o lakin -g users /home/lakin/.local/state
      install -d -o lakin -g users /home/lakin/.cache
      chown -R lakin:users \
        /home/lakin/.config \
        /home/lakin/.local \
        /home/lakin/.cache \
        /home/lakin/bin 2>/dev/null || true
    '';
  };
}
