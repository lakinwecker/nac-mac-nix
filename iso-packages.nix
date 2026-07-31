{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    vim
    gparted
    krita
    neovim
    thunderbird
    signal-desktop
    qogir-icon-theme
    fontconfig
    # Dev tools
    devenv
    ranger
    # Charm tools
    glow
    gum
    skate
    charm
    soft-serve
    vhs
    mods
    pop
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
