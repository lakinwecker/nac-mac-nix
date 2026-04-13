{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    vim
    gparted
    krita
    neovim
    thunderbird
    signal-desktop
    impala
    iwd
    qogir-icon-theme
    fontconfig
    # Dev tools
    devenv
    ranger
    # Neovim dependencies for LazyVim
    gcc
    gnumake
    ripgrep
    fd
    lazygit
    nodejs
    unzip
    wget
    curl
    jq
    tree-sitter
    # KVM
    lan-mouse
  ];

  # Docker
  virtualisation.docker.enable = true;
}
