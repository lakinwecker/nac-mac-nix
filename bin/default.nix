{ pkgs, username, ... }:
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
