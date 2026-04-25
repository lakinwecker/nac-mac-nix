{ ... }:
{
  # Kill runaway processes before the kernel OOM killer freezes the machine.
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
    ./packages.nix
    ./user.nix
    ../ghostty
    ../nvim
    ../fish
    ../nushell
    ../starship
    ../bin
    ../zellij
    ../ai
    ../latex
    ../libreoffice
  ];
}
