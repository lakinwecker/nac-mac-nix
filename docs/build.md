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

Hosts: cornfield gratch harry roach shrike souris trunkie
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

The installer ISO copies the flake to `/iso/flake`. From the live environment,
`cd /iso/flake` and use `install.sh` rather than calling `disko-install` directly —
it validates the disk arguments against the host's disko config, closes stale LUKS
mappings on the target disks, and prompts once for the passphrase.

```
Usage: ./install.sh <host> --disk [<name>=]<disk-id> [--disk <name>=<disk-id> ...] [--wipe]

  --disk [<name>=]<id>  A disk declared in the host's disko config. Repeatable.
                        Bare <id> with no name= prefix means "main".
  --home-disk <id>      Shorthand for --disk home=<id>
  --wipe                blkdiscard all target disks before formatting
```

Always pass `/dev/disk/by-id/...` paths. NVMe enumeration order is not stable
across boots, and `/dev/nvme0n1` on the live ISO may not be the drive you mean.

Each host declares its own set of named disks, and `install.sh` requires exactly
those names — no more, no fewer:

| Host | Disks | Layout |
|------|-------|--------|
| harry, shrike, souris, cornfield | `main` | `disko-config.nix` — 512M ESP + LUKS btrfs, subvolumes `/`, `/home`, `/nix` |
| gratch, roach | `main`, `home` | `hosts/<name>/disko-config.nix` — separate LUKS home drive |
| trunkie | `root0`, `root1`, `home0`, `home1` | `hosts/trunkie/disko-config.nix` — two btrfs RAID1 mirrors |

```bash
# single disk
./install.sh cornfield --disk /dev/disk/by-id/ata-SAMSUNG_... --wipe

# dual drive
./install.sh roach --disk /dev/disk/by-id/nvme-WD_... \
                   --home-disk /dev/disk/by-id/nvme-KINGSTON_... --wipe

# four disks, two mirrors
./install.sh trunkie --disk root0=/dev/disk/by-id/nvme-Force_MP500_... \
                     --disk root1=/dev/disk/by-id/ata-INTEL_SSDSC2CW240A3_... \
                     --disk home0=/dev/disk/by-id/nvme-ADATA_SX8200PNP_... \
                     --disk home1=/dev/disk/by-id/nvme-... --wipe
```

### Multi-device btrfs and disko ordering

disko has no dependency ordering for multi-device btrfs: its btrfs type
contributes no `deviceDependencies`, so devices are created in `lib.attrNames`
order — alphabetically. Any member that runs `mkfs.btrfs` must therefore sort
*after* the member it names in `extraArgs`, or that `/dev/mapper` node does not
exist yet and the install fails with the disks already repartitioned.

`hosts/trunkie/disko-config.nix` relies on this: `root0`/`home0` are LUKS-only
and `root1`/`home1` carry the btrfs content. Preserve that if you add or rename
mirror members.
