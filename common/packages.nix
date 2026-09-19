{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Shell extras
    nushell
    bash
    direnv
    keepassxc
    pass
    gnupg
    pinentry-curses
    # git itself comes from ../git (programs.git)
    curl
    openssh
    inxi
    dnsutils
    ripgrep
    fd
    fzf
    dust
    tree
    jq
    scc
    zip
    unzip
    # firefox comes from programs.firefox in ./desktop.nix
    chromium
    zathura
    glow
    yazi
    superfile
    adwaita-icon-theme
    gnome-themes-extra
    libnotify
  ];
}
