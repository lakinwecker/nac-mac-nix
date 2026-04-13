{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    ghostty
  ];

  environment.etc."ghostty/config".source = ./config;

  system.activationScripts.ghosttyConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o lakin -g users /home/lakin/.config
      install -d -o lakin -g users /home/lakin/.config/ghostty
      ln -sf /etc/ghostty/config /home/lakin/.config/ghostty/config
      chown -h lakin:users /home/lakin/.config/ghostty/config
    '';
  };
}
