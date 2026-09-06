{ pkgs, ollamaAccel ? "cpu", ... }:
let
  # services.ollama.acceleration is deprecated upstream in favour of picking the
  # package directly, so this maps the registry field onto the right derivation.
  ollamaPackage = {
    cpu  = pkgs.ollama-cpu;
    cuda = pkgs.ollama-cuda;
    rocm = pkgs.ollama-rocm;
  }.${ollamaAccel};
in
{
  services.ollama = {
    enable = true;
    package = ollamaPackage;
  };

  environment.systemPackages = with pkgs; [
    ollamaPackage
    python3Packages.huggingface-hub
    # rtk 0.43.0's test build trips newer rustc's dead-code denial
    # (`-D warnings`: FILTERS_TOML / load unused in the test profile).
    # The normal build is fine, so skip the check phase.
    (rtk.overrideAttrs (_: { doCheck = false; }))
  ];
}
