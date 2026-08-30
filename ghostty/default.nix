{ pkgs, username, ghosttyOpacity ? 0.85, ... }: {
  environment.systemPackages = with pkgs; [
    ghostty
  ];

  # toJSON, not toString — toString renders 0.95 as "0.950000".
  environment.etc."ghostty/config".text =
    builtins.readFile ./config
    + "background-opacity = ${builtins.toJSON ghosttyOpacity}\n";

  system.activationScripts.ghosttyConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${username} -g users /home/${username}/.config
      install -d -o ${username} -g users /home/${username}/.config/ghostty
      ln -sf /etc/ghostty/config /home/${username}/.config/ghostty/config
      chown -h ${username}:users /home/${username}/.config/ghostty/config
    '';
  };
}
