{ pkgs, lib, username, ... }:
let
  themeName  = "rose-pine-dawn";
  iconName   = "rose-pine-dawn";
  cursorName = "BreezeX-RosePineDawn-Linux";     # light variant from rose-pine-cursor
  wallpaper  = ./wallpapers/rose-pine/birb.png;  # CC0, see wallpapers/rose-pine/LICENSE
  # nixpkgs' rose-pine-gtk-theme skips the upstream Moon gnome-shell theme;
  # re-add it so User Themes can style the top bar. Upstream ships no light
  # (Dawn) shell theme, so the panel is Moon (dark) while apps stay Dawn.
  rosePineTheme = pkgs.rose-pine-gtk-theme.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      cp -r $src/gnome_shell/moon/gnome-shell $out/share/themes/rose-pine-moon/gnome-shell
    '';
  });
  gtk4css    = "${rosePineTheme}/share/themes/${themeName}/gtk-4.0/gtk.css";
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
    gnome-tweaks
    mpv     # video player (totem is excluded below)
    loupe   # GNOME image/photo viewer
    # Rosé Pine theming (Thunderbird is enabled via programs.thunderbird below)
    rosePineTheme
    rose-pine-icon-theme
    rose-pine-cursor
    # GNOME Shell extensions: hide the overview dash + apply the shell theme
    gnomeExtensions.just-perfection
    gnomeExtensions.user-themes
  ];

  # Remove GNOME bloat
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
    totem
  ];

  # ── Firefox: Rosé Pine Dawn (light) theme (souris only) ─────────────
  # Force-installs the AMO theme (merges with common/desktop.nix's
  # uBlock/Privacy Badger/Dark Reader) and sets it as the active theme.
  programs.firefox.policies.ExtensionSettings."{f2b68b20-da4c-4b95-af7e-430bb8d3d6ce}" = {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/rose-pine-dawn-light-theme/latest.xpi";
    installation_mode = "force_installed";
  };
  programs.firefox.preferences."extensions.activeThemeID" = "{f2b68b20-da4c-4b95-af7e-430bb8d3d6ce}";

  # ── Thunderbird: Rosé Pine Dawn theme (souris only) ─────────────────
  # programs.thunderbird installs a policy-aware Thunderbird; force-install
  # the ATN theme and set it active.
  programs.thunderbird = {
    enable = true;
    policies.ExtensionSettings."mrfallen45@gmail.com" = {
      install_url = "https://addons.thunderbird.net/thunderbird/downloads/file/1023044/rose_pine_dawn-1.0-tb.xpi";
      installation_mode = "force_installed";
    };
    preferences."extensions.activeThemeID" = "mrfallen45@gmail.com";
  };

  # ── Rosé Pine Dawn ──────────────────────────────────────────────────
  # These override the Adwaita-dark defaults from common/desktop.nix.
  # mkBefore places this database ahead of common's in the user profile,
  # so it wins on the shared keys (gtk-theme, color-scheme).
  programs.dconf.profiles.user.databases = lib.mkBefore [{
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-light";  # Dawn is a light flavor
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
        enabled-extensions = [
          "just-perfection-desktop@just-perfection"
          "user-theme@gnome-shell-extensions.gcampax.github.com"
        ];
      };
      "org/gnome/shell/extensions/just-perfection" = {
        dash = false;
      };
      # Top bar / shell theme. Upstream Rosé Pine ships only a Moon (dark)
      # gnome-shell theme, so the panel is dark while apps stay Dawn (light).
      "org/gnome/shell/extensions/user-theme" = {
        name = "rose-pine-moon";
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
