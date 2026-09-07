{ pkgs, username, ... }:
{
  environment.systemPackages = with pkgs; [
    zellij
  ];

  environment.etc."zellij/config.kdl".source = ./config.kdl;

  # Overrides for the built-in themes of the same name. zellij only honours
  # these from the theme directory — a `themes {}` block in config.kdl is
  # merged over by the built-ins. See the header of either file.
  environment.etc."zellij/themes/tokyo-night-storm.kdl".source = ./themes/tokyo-night-storm.kdl;
  environment.etc."zellij/themes/tokyo-night-light.kdl".source = ./themes/tokyo-night-light.kdl;

  system.activationScripts.zellijConfig = {
    deps = [ "users" ];
    text = ''
      ZELLIJ_CONFIG="/home/${username}/.config/zellij"
      # Unconditional, matching ../nvim and ../nushell. The previous
      # `if [ ! -d "$ZELLIJ_CONFIG" ]` guard meant any host that already had the
      # directory never received a file added here afterwards.
      mkdir -p "$ZELLIJ_CONFIG/themes"
      ln -sf /etc/zellij/config.kdl "$ZELLIJ_CONFIG/config.kdl"
      ln -sf /etc/zellij/themes/tokyo-night-storm.kdl "$ZELLIJ_CONFIG/themes/tokyo-night-storm.kdl"
      ln -sf /etc/zellij/themes/tokyo-night-light.kdl "$ZELLIJ_CONFIG/themes/tokyo-night-light.kdl"
      chown -R ${username}:users "$ZELLIJ_CONFIG"
    '';
  };
}
