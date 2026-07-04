# Build & Install

## build.sh

```
Usage: ./build.sh <action> [host...]

Actions:
  --iso       Build installer ISO(s)           (output: result-<host>/)
  --build     Build system toplevel (no switch)
  --switch    Build and switch (nixos-rebuild switch)
  --boot      Build and activate on next boot  (nixos-rebuild boot)
  --test      Build and activate now, no boot entry (nixos-rebuild test)
  --dry       Dry-run build (evaluation only)

Modifiers:
  --update    Refresh flake.lock (nix flake update) before a build action

Hosts: harry gratch trunkie roach cornfield
  No host given: defaults to all hosts for --iso/--dry,
  or the current hostname for --switch/--boot/--test/--build.
```

Examples:
```bash
./build.sh --iso cornfield    # build cornfield ISO
./build.sh --iso              # build all ISOs
./build.sh --switch           # switch this machine
./build.sh --dry harry        # dry-run evaluate harry
```

## Updating (bump flake inputs, then switch)

`--update` prefixes any build action and runs `nix flake update` first, so the
build picks up the latest nixpkgs/home-manager/etc. The lockfile is shared
across hosts, so it updates once no matter how many hosts you pass. `--update`
is rejected for `--install`/`--wipe`. **Commit the resulting `flake.lock`
yourself** — the script never touches git.

```bash
./build.sh --update --switch          # update inputs, switch this machine
./build.sh --update --switch gratch   # update inputs, switch gratch
./build.sh --update --boot trunkie    # update inputs, stage trunkie for next boot
```

`./update.sh` is a shortcut for the common case (`build.sh --update --switch`):

```bash
./update.sh          # update inputs, switch the current machine
./update.sh gratch   # update inputs, switch gratch
```

ISO output lands in `./result-<host>/iso/nixos-*.iso`. Write to USB with `dd`.

## Install

The installer ISO copies the flake to `/iso/flake`. From the live environment:

```bash
sudo disko-install --flake /iso/flake#harry --disk main /dev/disk/by-id/nvme-...
```

`disko-config.nix` defines the default partition layout (512M EFI + LUKS btrfs with `/`, `/home`, `/nix` subvolumes). LUKS password is read from `/tmp/disk-password` at install time. `roach` uses a separate dual-drive layout in `hosts/roach/disko-config.nix`. See `INSTALL.md`.
