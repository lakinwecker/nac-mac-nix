{ ... }:
{
  imports = [
    ./networking.nix
    ./desktop.nix
    ./audio.nix
    ./packages.nix
    ./user.nix
    ../hypr
    ../ghostty
    ../nvim
    ../fish
    ../starship
    ../bin
    ../zellij
  ];
}
