{ pkgs, lib, kagi ? true, ... }:
{
  hardware.graphics.enable = true;

  # gratch's lid/battery handling reads `upower --monitor`.
  services.upower.enable = true;

  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
      };
    }];
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # Search defaults live here, not in the profile: a profile reset silently
  # reverts the search engine to Google and nothing else puts it back.
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
        # Registers the "Kagi" engine named by SearchEngines.Default below.
        (extension "kagi-search-for-firefox" "search@kagi.com")
      ]);
    }
    # Must match the engine name the extension registers.
    // lib.optionalAttrs kagi {
      SearchEngines.Default = "Kagi";
    };
  };

  # Without this, xdg-open takes the first mimeinfo.cache match and chromium
  # sorts before firefox, stealing every link.
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };

  environment.sessionVariables.BROWSER = "firefox";

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
