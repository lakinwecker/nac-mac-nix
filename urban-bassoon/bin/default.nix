{ pkgs, ... }:
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
  ];
  scriptEntries = builtins.listToAttrs (map (name: {
    name = "user-bin/${name}";
    value = { source = ./scripts/${name}; };
  }) scripts);
in {
  environment.etc = scriptEntries;

  system.activationScripts.userBin = {
    deps = [ "users" ];
    text = ''
      BIN_DIR="/home/lakin/bin"
      mkdir -p "$BIN_DIR"
      for script in ${builtins.concatStringsSep " " scripts}; do
        TARGET="$BIN_DIR/$script"
        # Only symlink if target doesn't exist or is already a symlink (don't overwrite user scripts)
        if [ ! -e "$TARGET" ] || [ -L "$TARGET" ]; then
          ln -sf "/etc/user-bin/$script" "$TARGET"
        fi
      done
      chown -R lakin:users "$BIN_DIR"
    '';
  };
}
