# Install

The installer ISOs copy this flake to `/iso/flake`. Boot the target host's ISO,
then from the live environment run:

```bash
cd /iso/flake
./build.sh --install <host> [--disk <name> <device>]...
```

`--install` prompts for confirmation, then wipes every disk the host's disko
config references, LUKS-encrypts them, runs `disko` to format+mount, and calls
`nixos-install`.

## Per-host

### roach

Disks are hardcoded in `hosts/roach/disko-config.nix`, so nothing else is
needed:

```bash
./build.sh --install roach
```

### harry / gratch / trunkie

The generic `disko-config.nix` defaults to `/dev/nvme0n1`. Pass the real
by-id path so the installer doesn't depend on NVMe enumeration order:

```bash
ls /dev/disk/by-id/
./build.sh --install harry --disk main /dev/disk/by-id/nvme-SAMSUNG_MZVL2512...
```

## Partition layout

- `/boot` — 512 MiB EFI (vfat)
- LUKS-encrypted btrfs with subvolumes `/`, `/home`, `/nix` (and `/swap` where
  hibernate is used)

`roach` uses two separate LUKS+btrfs filesystems — main disk carries `/` and
`/nix`, second disk carries `/home`.

## Recovering from a failed install

If `--install` fails partway (stale LUKS headers, leftover mounts, etc.):

```bash
./build.sh --wipe <host> [--disk <name> <device>]...
```

Then re-run `--install`.

## First boot

Log in as `lakin` with password `changeme`, then `passwd`.
