{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    claude-code
    # Shell extras
    fish
    nushell
    bash
    keepassxc
    pass
    gnupg
    pinentry-curses
    # SSH tooling
    openssh
    # Hardware / system inspection
    inxi
    # Search / filesystem
    ripgrep
    fd
    fzf
    dust
    jq
    # TUI productivity
    lazygit
    lazydocker
    yazi
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
