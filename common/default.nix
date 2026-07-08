{ lib, devTools ? true, ... }:
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
    ../fish
    ../nushell
    ../starship
    ../bin
    ../libreoffice
  ]
  # Dev-only modules: LazyVim, zellij, ollama (ai/), texlive (latex/).
  # Skipped on trimmed machines (devTools = false).
  ++ lib.optionals devTools [
    ../nvim
    ../zellij
    ../ai
    ../latex
  ];
}
