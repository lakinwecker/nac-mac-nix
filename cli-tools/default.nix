# CLI / power-user tools, available on every machine.
#
# These used to be gated behind the `devTools` flag inside common/packages.nix,
# which left trimmed hosts (souris) without them. They're extracted here and
# imported unconditionally so every machine — trimmed or not — gets them.
# `devTools` now only gates the heavier editor/AI/LaTeX modules.
{ pkgs, username, ... }:
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
    dive      # inspect image layers
    # Dev runtimes / AI
    claude-code
    bun
    # Kubernetes
    kubectl
    kubie
    k9s
    kubernetes-helm
    # Databases
    pgcli
    lazysql
    # TUI misc
    ncmpcpp
    bluetuith
  ];

  environment.etc."kubie/kubie.yaml".text = ''
    prompt:
      disable: true
  '';

  system.activationScripts.kubieConfig = {
    deps = [ "users" ];
    text = ''
      KUBE_DIR="/home/${username}/.kube"
      KUBIE_CONFIG="$KUBE_DIR/kubie.yaml"
      if [ ! -e "$KUBIE_CONFIG" ]; then
        install -d -o ${username} -g users "$KUBE_DIR"
        ln -sf /etc/kubie/kubie.yaml "$KUBIE_CONFIG"
        chown -h ${username}:users "$KUBIE_CONFIG"
      fi
    '';
  };
}
