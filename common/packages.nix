{ pkgs, lib, devTools ? true, ... }:
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
  ]
  # Dev / power-user kitchen sink — skipped on trimmed machines.
  ++ lib.optionals devTools [
    claude-code
    bun
    # TUI productivity
    lazygit
    lazydocker
    ncmpcpp
    bluetuith
    impala
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
  ];
}
