# Pi coding agent (https://lazypi.org). Entry points: `pi` / `lazypi` in
# ../bin/scripts. node comes from ../iso-packages.nix and ../nvim.
{ username, ... }:
let
  npmPrefix = "/home/${username}/.npm-global";
in
{
  # npm's default prefix is the read-only nodejs derivation. Also set in the
  # wrappers, since this only reaches shells started after a fresh login.
  environment.sessionVariables.NPM_CONFIG_PREFIX = npmPrefix;

  # ../nushell/env.nu puts ${npmPrefix}/bin on PATH after ~/bin.
  system.activationScripts.npmGlobalPrefix = {
    deps = [ "users" ];
    text = ''
      install -d -o ${username} -g users ${npmPrefix} ${npmPrefix}/bin
    '';
  };
}
