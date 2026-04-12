# Force rebuild
{ pkgs, lib, hyprland, hyprgrass ? null, hyprHostConfig ? "", ... }:
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
        command = "Hyprland";
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
    networkmanagerapplet
    power-profiles-daemon
  ];

  environment.etc."hypr/hyprland.conf".text =
    builtins.readFile ./hyprland.conf
    + lib.optionalString hyprgrassEnabled (builtins.readFile ./hyprgrass.conf)
    + "\n# Per-host overrides\n" + hyprHostConfig;
  environment.etc."hypr/hypridle.conf".source = ./hypridle.conf;
  environment.etc."hypr/hyprlock.conf".source = ./hyprlock.conf;
  environment.etc."wallpaper.jpg".source = ./wallpaper.jpg;
  environment.etc."hyprpanel/config.json".source = ./hyprpanel-config.json;
  environment.etc."hyprpanel/custom.css".source = ./hyprpanel-custom.css;
  environment.etc."avatar.png".source = ./avatar.png;

  system.activationScripts.hyprConfig = {
    deps = [ "users" ];
    text = ''
      mkdir -p /home/lakin/.config/hypr
      mkdir -p /home/lakin/.config/hyprpanel/styles
      ln -sf /etc/hypr/hyprland.conf /home/lakin/.config/hypr/hyprland.conf
      ln -sf /etc/hypr/hypridle.conf /home/lakin/.config/hypr/hypridle.conf
      ln -sf /etc/hypr/hyprlock.conf /home/lakin/.config/hypr/hyprlock.conf
      # Force copy hyprpanel config (overwrite any existing)
      cp -f /etc/hyprpanel/config.json /home/lakin/.config/hyprpanel/config.json
      cp -f /etc/hyprpanel/custom.css /home/lakin/.config/hyprpanel/styles/custom.css
      # User avatar
      cp -f /etc/avatar.png /home/lakin/.face.icon
      chown lakin:users /home/lakin/.face.icon
      # Wallpaper for HyprPanel
      cp -f /etc/wallpaper.jpg /home/lakin/.config/background
      chown lakin:users /home/lakin/.config/background
      # Fix all hyprpanel permissions
      chown -R lakin:users /home/lakin/.config/hyprpanel
      chmod -R u+rw /home/lakin/.config/hyprpanel
    '';
  };
}
