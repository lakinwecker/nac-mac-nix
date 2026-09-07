# Backing config for the Pi coding agent, bootstrapped via LazyPi
# (https://lazypi.org). Entry points are the `pi` / `lazypi` wrappers in
# ../bin/scripts, gated on the same devTools flag as this module.
#
# No node package here: every machine already gets nodejs from
# ../iso-packages.nix (which mkInstalled imports too, not just mkIso), and these
# hosts also get nodejs_22 from ../nvim. Both clear LazyPi's >= 22.19 floor.
{ username, ... }:
let
  npmPrefix = "/home/${username}/.npm-global";
in
{
  # npm's default prefix is the nodejs derivation itself, which is read-only, so
  # LazyPi's `npm install -g @earendil-works/pi-coding-agent` fails without a
  # writable one. Set in the wrappers as well — this value only reaches shells
  # started after a fresh login, and never reaches devenv shells.
  environment.sessionVariables.NPM_CONFIG_PREFIX = npmPrefix;

  # ../nushell/env.nu puts ${npmPrefix}/bin on PATH after ~/bin, so the `pi`
  # wrapper keeps shadowing the binary it bootstraps.
  system.activationScripts.npmGlobalPrefix = {
    deps = [ "users" ];
    text = ''
      install -d -o ${username} -g users ${npmPrefix} ${npmPrefix}/bin
    '';
  };
}
