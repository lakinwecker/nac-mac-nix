{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    ghostty
  ];

  environment.etc."ghostty/config".source = ./config;

  system.activationScripts.ghosttyConfig = ''
    mkdir -p /home/lakin/.config/ghostty
    ln -sf /etc/ghostty/config /home/lakin/.config/ghostty/config
  '';
}
