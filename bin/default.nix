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
      BIN_DIR="/home/${username}/bin"
      install -d -o ${username} -g users "$BIN_DIR"
      for script in ${builtins.concatStringsSep " " scripts}; do
        TARGET="$BIN_DIR/$script"
        # Only symlink if target doesn't exist or is already a symlink (don't overwrite user scripts)
        if [ ! -e "$TARGET" ] || [ -L "$TARGET" ]; then
          ln -sf "/etc/user-bin/$script" "$TARGET"
          chown -h ${username}:users "$TARGET"
        fi
      done
    '';
  };
}
