{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Shell extras
    fish
    nushell
    bash
    direnv
    keepassxc
    pass
    gnupg
    pinentry-curses
    # Version control / net (were pulled in via nvim before it was gated)
    git
    curl
    # SSH tooling
    openssh
    # Hardware / system inspection
    inxi
    # DNS
    dnsutils
    # Search / filesystem
    ripgrep
    fd
    fzf
    dust
    tree      # classic; `eza --tree` (installed) is the Rust equivalent
    jq
    # Archives
    zip
    unzip
    # Docs
    zathura
    glow
    # File managers
    yazi
    superfile
    # Theming
    adwaita-icon-theme
    gnome-themes-extra
    libnotify
  ];
}
