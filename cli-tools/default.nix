# CLI / power-user tools, available on every machine.
#
# These used to be gated behind the `devTools` flag inside common/packages.nix,
# which left trimmed hosts (souris) without them. They're extracted here and
# imported unconditionally so every machine — trimmed or not — gets them.
# `devTools` now only gates the heavier editor/AI/LaTeX modules.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # System monitor
    btop
    # Git / GitHub
    lazygit
    gh
    gh-dash
    # Docker
    lazydocker
    # Dev runtimes / AI
    claude-code
    bun
    # Kubernetes
    kubectl
    k9s
    kubernetes-helm
    # Databases
    pgcli
    lazysql
    # TUI misc
    ncmpcpp
    bluetuith
    impala
  ];
}
