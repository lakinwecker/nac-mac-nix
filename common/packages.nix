{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    claude-code
    bun
    # Shell extras
    fish
    nushell
    bash
    direnv
    keepassxc
    pass
    gnupg
    pinentry-curses
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
    jq
    # Archives
    zip
    unzip
    # Docs
    zathura
    # TUI productivity
    lazygit
    lazydocker
    yazi
    superfile
    ncmpcpp
    bluetuith
    impala
    glow
    # GitHub
    gh
    gh-dash
    # Kubernetes
    kubectl
    k9s
    kubernetes-helm
    # Databases
    pgcli
    lazysql
    # Theming
    adwaita-icon-theme
    gnome-themes-extra
    libnotify
  ];
}
