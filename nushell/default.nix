{ pkgs, username, ... }:
let
  starshipNu = pkgs.runCommand "starship-init.nu" { } ''
    ${pkgs.starship}/bin/starship init nu > $out
  '';
  zoxideNu = pkgs.runCommand "zoxide-init.nu" { } ''
    ${pkgs.zoxide}/bin/zoxide init nushell > $out
  '';

  # Skip the +ssh-cache shortcut: it never expires, so a host that loses its
  # terminfo gets TERM=xterm-ghostty forever. The remote probe reuses ControlMaster,
  # and requires cup= so a capability-less stub entry counts as missing.
  ghosttyNu = pkgs.runCommand "ghostty.nu" { } ''
    substitute \
      ${pkgs.ghostty}/share/ghostty/shell-integration/nushell/vendor/autoload/ghostty.nu \
      $out \
      --replace-fail '$env.GHOSTTY_SHELL_FEATURES |' '$env.GHOSTTY_SHELL_FEATURES? |' \
      --replace-fail '(^$ghostty "+ssh-cache" $"--host=($ssh_id)" | complete | $in.exit_code == 0)' 'false' \
      --replace-fail 'print $"Setting up xterm-ghostty terminfo on ($ssh_cfg.hostname)..."' "" \
      --replace-fail 'infocmp xterm-ghostty >/dev/null 2>&1 && exit 0' 'infocmp xterm-ghostty 2>/dev/null | grep -q cup= && exit 0' \
      --replace-fail 'tic -x - 2>/dev/null && exit 0' 'tic -x - 2>/dev/null && infocmp xterm-ghostty 2>/dev/null | grep -q cup= && exit 0'
  '';
in
{
  # Backing binaries for config.nu's aliases and the zoxide/starship inits.
  environment.systemPackages = with pkgs; [
    eza
    bat
    zoxide
  ];

  environment.etc."nushell-user/config.nu".source = ./config.nu;
  environment.etc."nushell-user/env.nu".source = ./env.nu;
  environment.etc."nushell-user/starship.nu".source = starshipNu;
  environment.etc."nushell-user/zoxide.nu".source = zoxideNu;
  environment.etc."nushell-user/ghostty.nu".source = ghosttyNu;

  system.activationScripts.nushellConfig = {
    deps = [ "users" ];
    text = ''
      NU_CONFIG="/home/${username}/.config/nushell"
      mkdir -p "$NU_CONFIG"
      ln -sf /etc/nushell-user/config.nu "$NU_CONFIG/config.nu"
      ln -sf /etc/nushell-user/env.nu "$NU_CONFIG/env.nu"
      ln -sf /etc/nushell-user/starship.nu "$NU_CONFIG/starship.nu"
      ln -sf /etc/nushell-user/zoxide.nu "$NU_CONFIG/zoxide.nu"
      ln -sf /etc/nushell-user/ghostty.nu "$NU_CONFIG/ghostty.nu"
      chown -R ${username}:users "$NU_CONFIG"
    '';
  };
}
