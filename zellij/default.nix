{ pkgs, username, ... }:
{
  environment.systemPackages = with pkgs; [
    zellij
  ];

  environment.etc."zellij/config.kdl".source = ./config.kdl;

  # Must live in the theme dir: built-ins override a `themes {}` block in config.kdl.
  environment.etc."zellij/themes/tokyo-night-storm.kdl".source = ./themes/tokyo-night-storm.kdl;
  environment.etc."zellij/themes/tokyo-night-light.kdl".source = ./themes/tokyo-night-light.kdl;

  system.activationScripts.zellijConfig = {
    deps = [ "users" ];
    text = ''
      ZELLIJ_CONFIG="/home/${username}/.config/zellij"
      mkdir -p "$ZELLIJ_CONFIG/themes"
      ln -sf /etc/zellij/config.kdl "$ZELLIJ_CONFIG/config.kdl"
      ln -sf /etc/zellij/themes/tokyo-night-storm.kdl "$ZELLIJ_CONFIG/themes/tokyo-night-storm.kdl"
      ln -sf /etc/zellij/themes/tokyo-night-light.kdl "$ZELLIJ_CONFIG/themes/tokyo-night-light.kdl"
      chown -R ${username}:users "$ZELLIJ_CONFIG"
    '';
  };
}
