# Force rebuild
{ pkgs, hyprland, hyprgrass, ... }:
let
  hyprgrassPlugin = hyprgrass.packages.${pkgs.system}.default;
in {
  imports = [ hyprland.nixosModules.default ];

  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  # Make plugin path available
  environment.etc."hypr/plugins/hyprgrass.so".source = "${hyprgrassPlugin}/lib/libhyprgrass.so";

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "Hyprland";
        user = "nixos";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    nwg-drawer
    onagre
    dunst
    hyprlock
    hypridle
    hyprpaper
    eww
    playerctl
    brightnessctl
    wl-clipboard
    grim
    slurp
    python3
    socat
    wvkbd
    iio-hyprland
    # For eww scripts
    gawk
    procps
    gnugrep
    coreutils
  ];

  environment.etc."hypr/hyprland.conf".source = ./hyprland.conf;
  environment.etc."hypr/hypridle.conf".source = ./hypridle.conf;
  environment.etc."hypr/hyprlock.conf".source = ./hyprlock.conf;
  environment.etc."hypr/hyprpaper.conf".text = ''
    preload = /etc/wallpaper.jpg
    wallpaper = ,/etc/wallpaper.jpg
    ipc = off
  '';
  environment.etc."wallpaper.jpg".source = ./wallpaper.jpg;

  environment.etc."eww/eww.yuck".source = ./eww/eww.yuck;
  environment.etc."eww/eww.scss".source = ./eww/eww.scss;
  environment.etc."eww/scripts/battery" = {
    source = ./eww/scripts/battery;
    mode = "0755";
  };
  environment.etc."eww/scripts/mem-ad" = {
    source = ./eww/scripts/mem-ad;
    mode = "0755";
  };
  environment.etc."eww/scripts/memory" = {
    source = ./eww/scripts/memory;
    mode = "0755";
  };
  environment.etc."eww/scripts/music_info" = {
    source = ./eww/scripts/music_info;
    mode = "0755";
  };
  environment.etc."eww/scripts/pop" = {
    source = ./eww/scripts/pop;
    mode = "0755";
  };
  environment.etc."eww/scripts/time" = {
    source = ./eww/scripts/time;
    mode = "0755";
  };
  environment.etc."eww/scripts/wifi" = {
    source = ./eww/scripts/wifi;
    mode = "0755";
  };
  environment.etc."eww/scripts/workspace.py" = {
    source = ./eww/scripts/workspace.py;
    mode = "0755";
  };

  system.activationScripts.hyprConfig = ''
    mkdir -p /home/nixos/.config/hypr
    mkdir -p /home/nixos/.config/eww/scripts
    ln -sf /etc/hypr/hyprland.conf /home/nixos/.config/hypr/hyprland.conf
    ln -sf /etc/hypr/hypridle.conf /home/nixos/.config/hypr/hypridle.conf
    ln -sf /etc/hypr/hyprlock.conf /home/nixos/.config/hypr/hyprlock.conf
    ln -sf /etc/hypr/hyprpaper.conf /home/nixos/.config/hypr/hyprpaper.conf
    ln -sf /etc/eww/eww.yuck /home/nixos/.config/eww/eww.yuck
    ln -sf /etc/eww/eww.scss /home/nixos/.config/eww/eww.scss
    ln -sf /etc/eww/scripts/battery /home/nixos/.config/eww/scripts/battery
    ln -sf /etc/eww/scripts/mem-ad /home/nixos/.config/eww/scripts/mem-ad
    ln -sf /etc/eww/scripts/memory /home/nixos/.config/eww/scripts/memory
    ln -sf /etc/eww/scripts/music_info /home/nixos/.config/eww/scripts/music_info
    ln -sf /etc/eww/scripts/pop /home/nixos/.config/eww/scripts/pop
    ln -sf /etc/eww/scripts/time /home/nixos/.config/eww/scripts/time
    ln -sf /etc/eww/scripts/wifi /home/nixos/.config/eww/scripts/wifi
    ln -sf /etc/eww/scripts/workspace.py /home/nixos/.config/eww/scripts/workspace.py
  '';
}
