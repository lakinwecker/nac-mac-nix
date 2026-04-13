# Force rebuild
{ pkgs, lib, hyprland, hyprgrass ? null, hyprHostConfig ? "", hyprWallpaper ? ./wallpaper.jpg, ... }:
let
  hyprgrassEnabled = hyprgrass != null;
in {
  imports = [ hyprland.nixosModules.default ];

  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  environment.etc."hypr/plugins/hyprgrass.so" = lib.mkIf hyprgrassEnabled {
    source = "${hyprgrass.packages.${pkgs.system}.default}/lib/libhyprgrass.so";
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${hyprland.packages.${pkgs.system}.hyprland}/bin/start-hyprland";
        user = "lakin";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    hyprshell
    onagre
    bibata-cursors
    hyprlock
    hypridle
    hyprpolkitagent
    hyprpanel
    playerctl
    brightnessctl
    wl-clipboard
    wtype
    grim
    slurp
    wf-recorder
    python3
    socat
    wvkbd
    iio-hyprland
    # Must-have utilities
    xdg-desktop-portal-gtk
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    # HyprPanel optional deps
    hyprsunset
    pywal
    swww
    matugen
    grimblast
    hyprpicker
    btop
    bluez
    bluez-tools
    power-profiles-daemon
  ];

  environment.etc."hypr/scripts/mac-shortcut.sh" = {
    source = ./scripts/mac-shortcut.sh;
    mode = "0755";
  };

  environment.etc."hypr/hyprland.conf".text =
    builtins.readFile ./hyprland.conf
    + lib.optionalString hyprgrassEnabled (builtins.readFile ./hyprgrass.conf)
    + "\n# Per-host overrides\n" + hyprHostConfig;
  environment.etc."hypr/hypridle.conf".source = ./hypridle.conf;
  environment.etc."hypr/hyprlock.conf".source = ./hyprlock.conf;
  environment.etc."wallpaper.jpg".source = hyprWallpaper;
  environment.etc."hyprpanel/config.json".source = ./hyprpanel-config.json;
  environment.etc."hyprpanel/custom.css".source = ./hyprpanel-custom.css;
  environment.etc."avatar.png".source = ./avatar.png;

  system.activationScripts.hyprConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o lakin -g users /home/lakin/.config
      install -d -o lakin -g users /home/lakin/.config/hypr
      install -d -o lakin -g users /home/lakin/.config/hyprpanel
      install -d -o lakin -g users /home/lakin/.config/hyprpanel/styles
      ln -sf /etc/hypr/hyprland.conf /home/lakin/.config/hypr/hyprland.conf
      ln -sf /etc/hypr/hypridle.conf /home/lakin/.config/hypr/hypridle.conf
      ln -sf /etc/hypr/hyprlock.conf /home/lakin/.config/hypr/hyprlock.conf
      chown -h lakin:users /home/lakin/.config/hypr/hyprland.conf /home/lakin/.config/hypr/hypridle.conf /home/lakin/.config/hypr/hyprlock.conf
      install -m 0644 -o lakin -g users /etc/hyprpanel/config.json /home/lakin/.config/hyprpanel/config.json
      install -m 0644 -o lakin -g users /etc/hyprpanel/custom.css /home/lakin/.config/hyprpanel/styles/custom.css
      install -m 0644 -o lakin -g users /etc/avatar.png /home/lakin/.face.icon
      install -m 0644 -o lakin -g users /etc/wallpaper.jpg /home/lakin/.config/background
    '';
  };
}
