{ pkgs, lib, kagi ? true, ... }:
{
  # ── Graphics ────────────────────────────────────────────────────────
  hardware.graphics.enable = true;

  # ── Power ───────────────────────────────────────────────────────────
  # Battery reporting for laptops and for Bluetooth devices (gratch also
  # drives its lid/battery handling off `upower --monitor`).
  services.upower.enable = true;

  # ── GTK / dconf ────────────────────────────────────────────────────
  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
      };
    }];
  };

  # ── Qt ──────────────────────────────────────────────────────────────
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # ── Firefox ─────────────────────────────────────────────────────────
  # Search defaults live here rather than in the profile: a profile reset (a
  # `firstrun-created-default` after an upgrade, say) silently takes the search
  # engine back to Google, and nothing outside this file puts it back.
  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = let
        extension = shortId: uuid: {
          name = uuid;
          value = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${shortId}/latest.xpi";
            installation_mode = "force_installed";
          };
        };
      in builtins.listToAttrs ([
        (extension "ublock-origin" "uBlock0@raymondhill.net")
        (extension "privacy-badger17" "jid1-MnnxcxisBPnSXQ@jetpack")
        (extension "darkreader" "addon@darkreader.org")
      ] ++ lib.optionals kagi [
        # Registers the "Kagi" engine that SearchEngines.Default names below,
        # and carries the session token so search works without a separate login.
        (extension "kagi-search-for-firefox" "search@kagi.com")
      ]);
    }
    # SearchEngines was ESR-only until Firefox 139; it applies on release now.
    # The string has to match the engine name the extension registers.
    // lib.optionalAttrs kagi {
      SearchEngines.Default = "Kagi";
    };
  };

  # ── Default browser ─────────────────────────────────────────────────
  # Without an explicit default, xdg-open picks the first app in
  # mimeinfo.cache that claims the scheme, and chromium sorts before
  # firefox — so installing chromium silently steals every link.
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };

  environment.sessionVariables.BROWSER = "firefox";

  # ── Fonts ───────────────────────────────────────────────────────────
  fonts.fontconfig.enable = true;
  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.inconsolata
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.ubuntu
    noto-fonts
    noto-fonts-color-emoji
    inconsolata
    iosevka
  ];
}
