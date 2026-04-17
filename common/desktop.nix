{ pkgs, ... }:
{
  # ── Graphics ────────────────────────────────────────────────────────
  hardware.graphics.enable = true;

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
      in builtins.listToAttrs [
        (extension "ublock-origin" "uBlock0@raymondhill.net")
        (extension "privacy-badger17" "jid1-MnnxcxisBPnSXQ@jetpack")
        (extension "darkreader" "addon@darkreader.org")
      ];
    };
  };

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
