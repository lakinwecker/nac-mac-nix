{ pkgs, lib, username, ... }:
let
  themeName  = "rose-pine-moon";
  iconName   = "rose-pine-moon";
  cursorName = "BreezeX-RosePine-Linux";        # dark variant from rose-pine-cursor
  wallpaper  = ./wallpapers/rose-pine/birb.png;  # CC0, see wallpapers/rose-pine/LICENSE
  gtk4css    = "${pkgs.rose-pine-gtk-theme}/share/themes/${themeName}/gtk-4.0/gtk.css";
in
{
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  # GNOME requires NetworkManager.
  # Priority 49 beats the mkForce (priority 50) in common/networking.nix.
  networking.networkmanager.enable = lib.mkOverride 49 true;
  networking.wireless.iwd.enable = lib.mkOverride 49 false;
  networking.useNetworkd = lib.mkOverride 49 false;
  systemd.network.enable = lib.mkOverride 49 false;

  environment.systemPackages = with pkgs; [
    gimp
    thunderbird
    gnome-tweaks
    mpv     # video player (totem is excluded below)
    loupe   # GNOME image/photo viewer
    # Rosé Pine Moon theming
    rose-pine-gtk-theme
    rose-pine-icon-theme
    rose-pine-cursor
    # Hides the overview dash (see dconf below)
    gnomeExtensions.just-perfection
  ];

  # Remove GNOME bloat
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
    totem
  ];

  # ── Rosé Pine Moon ──────────────────────────────────────────────────
  # These override the Adwaita-dark defaults from common/desktop.nix.
  # mkBefore places this database ahead of common's in the user profile,
  # so it wins on the shared keys (gtk-theme, color-scheme).
  programs.dconf.profiles.user.databases = lib.mkBefore [{
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";   # Moon is a dark flavor
        gtk-theme    = themeName;
        icon-theme   = iconName;
        cursor-theme = cursorName;
        accent-color = "pink";          # GNOME 47+ libadwaita accent; ignored if unsupported
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
      # Just Perfection: hide the dash (favorites bar) from the Activities
      # overview. Anita wants the window picker + search, not the dock.
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [ "just-perfection-desktop@just-perfection" ];
      };
      "org/gnome/shell/extensions/just-perfection" = {
        dash = false;
      };
    };
  }];

  # libadwaita (GTK4) apps ignore the GTK theme; they only read
  # ~/.config/gtk-4.0/gtk.css. Link the theme's palette there so Files,
  # Settings, Text Editor, etc. pick up the Rosé Pine colors too.
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
