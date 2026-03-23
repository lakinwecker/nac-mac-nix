{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    vim
    gparted
    krita
    neovim
    thunderbird
    firefox
    networkmanager
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
    tree-sitter
  ];

  # Docker
  virtualisation.docker.enable = true;
}
