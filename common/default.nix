{ lib, devTools ? true, ... }:
{
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  imports = [
    ./networking.nix
    ./desktop.nix
    ./audio.nix
    ./bluetooth.nix
    ./packages.nix
    ./user.nix
    ../ghostty
    ../git
    ../nushell
    ../starship
    ../bin
    ../libreoffice
    ../cli-tools
    ../tools
  ]
  ++ lib.optionals devTools [
    ../nvim
    ../zellij
    ../ai
    ../latex
    ../pi
  ];
}
