{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    eza
    bat
    starship
    ponysay
    difftastic
  ];

  environment.etc."fish-user/config.fish".source = ./config.fish;
  environment.etc."fish-user/aliases.fish".source = ./aliases.fish;

  system.activationScripts.fishConfig = {
    deps = [ "users" ];
    text = ''
      FISH_CONFIG="/home/lakin/.config/fish"
      if [ ! -d "$FISH_CONFIG" ]; then
        mkdir -p "$FISH_CONFIG"
        ln -sf /etc/fish-user/config.fish "$FISH_CONFIG/config.fish"
        ln -sf /etc/fish-user/aliases.fish "$FISH_CONFIG/aliases.fish"
        chown -R lakin:users "$FISH_CONFIG"
      fi
    '';
  };
}
