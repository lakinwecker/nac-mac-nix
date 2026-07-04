{ pkgs, ollamaCuda ? false, ... }:
{
  services.ollama = {
    enable = true;
    package = if ollamaCuda then pkgs.ollama-cuda else pkgs.ollama-cpu;
  };

  environment.systemPackages = with pkgs; [
    (if ollamaCuda then ollama-cuda else ollama-cpu)
    python3Packages.huggingface-hub
    rtk
  ];
}
