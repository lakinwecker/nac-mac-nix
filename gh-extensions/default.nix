# gh extensions, installed from nixpkgs rather than `gh extension install`.
# gh finds extensions only under ~/.local/share/gh/extensions/<name>/<name>,
# never on PATH, so the symlinks are what make `gh dash` / `gh enhance` resolve.
{ pkgs, username, ... }:
let
  extensions = with pkgs; [ gh-dash gh-enhance ];
  home = "/home/${username}";
  extDir = "${home}/.local/share/gh/extensions";
in
{
  environment.systemPackages = extensions;

  system.activationScripts.ghExtensions = {
    deps = [ "users" ];
    text = ''
      for d in .local .local/share .local/share/gh .local/share/gh/extensions; do
        install -d -o ${username} -g users ${home}/$d
      done
    ''
    + pkgs.lib.concatMapStrings (p: ''
      install -d -o ${username} -g users ${extDir}/${p.pname}
      ln -sfn ${p}/bin/${p.pname} ${extDir}/${p.pname}/${p.pname}
      chown -h ${username}:users ${extDir}/${p.pname}/${p.pname}
    '') extensions;
  };
}
