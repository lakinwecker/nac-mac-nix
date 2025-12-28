{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    kitty
  ];

  environment.etc."kitty/kitty.conf".source = ./kitty.conf;

  system.activationScripts.kittyConfig = ''
    mkdir -p /home/nixos/.config/kitty
    ln -sf /etc/kitty/kitty.conf /home/nixos/.config/kitty/kitty.conf
  '';
}
