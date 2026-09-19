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
    rsync  # backup.sh restore; cryptsetup/btrfs-progs come from the installer profile
    lan-mouse
  ];

  virtualisation.docker.enable = true;
}
