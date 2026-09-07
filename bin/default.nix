{ pkgs, lib, username, devTools ? true, ... }:
let
  scripts = [
    "ponymake"
    "ponycargo"
    "ponyyarn"
    "ponypnpm"
    "ponycmake"
    "ponyfly"
    "ponyinvoke"
    "ponybloop"
    "ponypodman"
    "wayshot-select"
    "wl-present"
    "mv-slugify"
    "battery"
    "ssh-agent-work"
    "ssh-agent-all"
    "theme-toggle"
    "toggle-keeb"
    "rotate-screen"
    "no-idle"
  ]
  # Gated individually because this module itself is imported unconditionally:
  # these are ../pi's entry points, and ../pi is devTools-only.
  ++ lib.optionals devTools [
    "pi"
    "lazypi"
  ];
  mkScript = name: pkgs.writeTextFile {
    inherit name;
    text = builtins.readFile ./scripts/${name};
    executable = true;
    destination = "/bin/${name}";
  };
in {
  # The pony* wrappers shell out to ponysay.
  environment.systemPackages = with pkgs; [ ponysay ] ++ map mkScript scripts;

  system.activationScripts.userBinCleanup = {
    deps = [ "users" ];
    text = ''
      BIN_DIR="/home/${username}/bin"
      for script in ${builtins.concatStringsSep " " scripts}; do
        TARGET="$BIN_DIR/$script"
        if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "/etc/user-bin/$script" ]; then
          rm -f "$TARGET"
        fi
      done
    '';
  };
}
