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
  ];
}
