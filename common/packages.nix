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
    # Version control / net (were pulled in via nvim before it was gated)
    # git itself comes from ../git (programs.git)
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
    scc       # code line counter
    # Archives
    zip
    unzip
    # Browsers — firefox comes from programs.firefox in ./desktop.nix
    chromium
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
