{ pkgs, ollamaCuda ? false, ... }:
{
  services.ollama = {
    enable = true;
    package = if ollamaCuda then pkgs.ollama-cuda else pkgs.ollama-cpu;
  };

  environment.systemPackages = with pkgs; [
    (if ollamaCuda then ollama-cuda else ollama-cpu)
    python3Packages.huggingface-hub
    # rtk 0.43.0's test build trips newer rustc's dead-code denial
    # (`-D warnings`: FILTERS_TOML / load unused in the test profile).
    # The normal build is fine, so skip the check phase.
    (rtk.overrideAttrs (_: { doCheck = false; }))
  ];
}
