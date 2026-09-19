{ pkgs, lib, username, ... }:
let
  themeName  = "rose-pine-dawn";
  iconName   = "rose-pine-dawn";
  cursorName = "BreezeX-RosePineDawn-Linux";     # light variant from rose-pine-cursor
  wallpaper  = ./wallpapers/rose-pine/birb.png;  # CC0, see wallpapers/rose-pine/LICENSE
  rosePineTheme = pkgs.callPackage ./rose-pine-theme.nix {
    rose-pine-gtk-theme = pkgs.callPackage ./rose-pine-gtk-theme.nix { };
  };
  gtk4css    = "${rosePineTheme}/share/themes/${themeName}/gtk-4.0/gtk.css";
in
{
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  environment.systemPackages = with pkgs; [
    gimp
    gnome-tweaks
    mpv
    loupe
    rosePineTheme
    rose-pine-icon-theme
    rose-pine-cursor
    gnomeExtensions.just-perfection
    gnomeExtensions.user-themes
  ];

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
    totem
  ];

  # Rosé Pine Dawn; merges with common/desktop.nix's extension set.
  programs.firefox.policies.ExtensionSettings."{f2b68b20-da4c-4b95-af7e-430bb8d3d6ce}" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/rose-pine-dawn-light-theme/latest.xpi";
    installation_mode = "force_installed";
  };
  programs.firefox.preferences."extensions.activeThemeID" = "{f2b68b20-da4c-4b95-af7e-430bb8d3d6ce}";

  programs.thunderbird = {
    enable = true;
    policies.ExtensionSettings."mrfallen45@gmail.com" = {
      install_url = "https://addons.thunderbird.net/thunderbird/downloads/file/1023044/rose_pine_dawn-1.0-tb.xpi";
      installation_mode = "force_installed";
    };
    preferences."extensions.activeThemeID" = "mrfallen45@gmail.com";
  };

  # mkBefore so these win over common/desktop.nix's Adwaita-dark defaults.
  programs.dconf.profiles.user.databases = lib.mkBefore [{
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-light";
        gtk-theme    = themeName;
        icon-theme   = iconName;
        cursor-theme = cursorName;
        accent-color = "pink";          # GNOME 47+ libadwaita; ignored if unsupported
      };
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
      };
      "org/gnome/desktop/background" = {
        picture-uri      = "file://${wallpaper}";
        picture-uri-dark = "file://${wallpaper}";
        picture-options  = "zoom";
      };
      "org/gnome/desktop/screensaver" = {
        picture-uri     = "file://${wallpaper}";
        picture-options = "zoom";
      };
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "just-perfection-desktop@just-perfection"
          "user-theme@gnome-shell-extensions.gcampax.github.com"
        ];
      };
      "org/gnome/shell/extensions/just-perfection" = {
        dash = false;
      };
      "org/gnome/shell/extensions/user-theme" = {
        name = "rose-pine-moon";
      };
    };
  }];

  # libadwaita (GTK4) apps ignore the GTK theme and only read this path.
  system.activationScripts.rosePineGtk4 = {
    deps = [ "users" ];
    text = ''
      cfg=/home/${username}/.config/gtk-4.0
      install -d -o ${username} -g users "$cfg"
      ln -sfn ${gtk4css} "$cfg/gtk.css"
      chown -h ${username}:users "$cfg/gtk.css"
    '';
  };
}
