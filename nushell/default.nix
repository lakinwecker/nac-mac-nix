{ pkgs, username, ... }:
let
  starshipNu = pkgs.runCommand "starship-init.nu" { } ''
    ${pkgs.starship}/bin/starship init nu > $out
  '';
  zoxideNu = pkgs.runCommand "zoxide-init.nu" { } ''
    ${pkgs.zoxide}/bin/zoxide init nushell > $out
  '';
in
{
  environment.etc."nushell-user/config.nu".source = ./config.nu;
  environment.etc."nushell-user/env.nu".source = ./env.nu;
  environment.etc."nushell-user/starship.nu".source = starshipNu;
  environment.etc."nushell-user/zoxide.nu".source = zoxideNu;
  environment.etc."nushell-user/ghostty.nu".source =
    "${pkgs.ghostty}/share/ghostty/shell-integration/nushell/vendor/autoload/ghostty.nu";

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
