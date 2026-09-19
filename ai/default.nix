{ pkgs, ollamaAccel ? "cpu", ... }:
let
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
    # rtk 0.43.0's tests trip newer rustc's dead-code denial; normal build is fine.
    (rtk.overrideAttrs (_: { doCheck = false; }))
  ];
}
