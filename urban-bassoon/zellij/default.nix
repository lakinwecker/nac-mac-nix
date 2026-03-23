{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    zellij
  ];

  environment.etc."zellij/config.kdl".source = ./config.kdl;

  system.activationScripts.zellijConfig = {
    deps = [ "users" ];
    text = ''
      ZELLIJ_CONFIG="/home/lakin/.config/zellij"
      if [ ! -d "$ZELLIJ_CONFIG" ]; then
        mkdir -p "$ZELLIJ_CONFIG"
        ln -sf /etc/zellij/config.kdl "$ZELLIJ_CONFIG/config.kdl"
        chown -R lakin:users "$ZELLIJ_CONFIG"
      fi
    '';
  };
}
