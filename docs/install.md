# Install

The installer ISOs copy this flake to `/iso/flake`. Boot the target host's ISO,
then from the live environment:

```bash
cd /iso/flake
./install.sh <host> --disk [<name>=]<disk-id> [--disk <name>=<disk-id>]... [--wipe]
```

`install.sh` checks the disk names against the host's disko config, prompts for
confirmation and a LUKS passphrase, closes any stale mappings on the target
disks, then runs `disko-install` to partition, encrypt, format, mount and
`nixos-install`.

The flake baked into the ISO is a snapshot taken at ISO build time. Editing a
disko config in the repo does not change an ISO already written to USB — rebuild
it. See [build.md](build.md).

The install needs working networking: `nixos-install` evaluates the host config
and fetches its closure, and the ISO carries the flake source but not its
inputs. Check `ping -c2 cache.nixos.org` before starting.

## Disk arguments

Each `<name>` is a disk declared in that host's disko config. A bare `<disk-id>`
with no `name=` prefix means `main`. `--home-disk <id>` is shorthand for
`--disk home=<id>`. Names are validated before anything is written, and a
mismatch lists what was declared, supplied, missing and unknown.

Always pass `/dev/disk/by-id/...` paths rather than `/dev/sda` — NVMe and SATA
enumeration order is not stable across boots, and the ISO itself occupies a
device node.

`--wipe` runs `blkdiscard` on each target disk first. Only the disks named on
the command line are ever touched.

## Per-host

Single-disk hosts (`harry`, `cornfield`, `souris`) declare one disk, `main`:

```bash
ls /dev/disk/by-id/
./install.sh harry --disk /dev/disk/by-id/nvme-SAMSUNG_MZVL2512... --wipe
```

Dual-disk hosts (`gratch`, `roach`) declare `main` and `home`:

```bash
./install.sh roach --disk <main-id> --home-disk <home-id> --wipe
```

`trunkie` declares three, named explicitly. These are its actual drives — check
them against `ls /dev/disk/by-id/` before running, and see
[trunkie-plan.md](trunkie-plan.md) for the reasoning behind the layout:

```bash
./install.sh trunkie \
  --disk root=/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_2042E2801181 \
  --disk home0=/dev/disk/by-id/nvme-ADATA_SX8200PNP_2L272L19EGUD \
  --disk home1=/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_23090Q800080
```

`root` is the WD SN550 931G, `home0` the ADATA SX8200 1.9T, `home1` the WD Black
SN770 1.8T. The two `ata-ST4000VN006-3CW104_*` IronWolfs are the backup pool and
must never appear in this command.

## Partition layout

Layouts live in each host's disko config: `hosts/<name>/disko-config.nix` where
the machine sets `diskoConfig`, otherwise the top-level `disko-config.nix`.

The generic single-disk layout is a 512 MiB EFI ESP plus a LUKS-encrypted btrfs
volume with subvolumes `/`, `/home` and `/nix` — and `/swap` on hosts that
hibernate, `harry` being the one that does.

`gratch` and `roach` use two separate LUKS+btrfs filesystems: the main disk
carries `/` and `/nix`, the second carries `/home`.

`trunkie` uses three disks — an unmirrored root, and `/home` as a btrfs RAID1
mirror across two LUKS members.

## Recovering from a failed install

Re-running `install.sh` is normally enough: it unmounts `/mnt` and closes any
LUKS mapping backed by a target disk before it starts. Mappings the operator
opened by hand on other disks are left alone.

If a disk is left in a state disko will not overwrite, add `--wipe`.

## Restoring data

`backup.sh` can pull `/home` back out of the backup pool. Easiest after the
first boot, from a TTY, before logging into the desktop.

**Keep the installer USB plugged in through that first reboot.** `backup.sh`
ships in this flake, which lives under the `/home` being restored, and the git
remote is SSH-only with its key in that same home — so neither a local copy nor
a clone is available on a fresh install. The ISO carries the flake at `/flake`,
which is the way back in:

```bash
lsblk -o NAME,SIZE,LABEL,FSTYPE
sudo mkdir -p /mnt/usb
sudo mount -o ro /dev/sdX1 /mnt/usb
cp -r /mnt/usb/flake /tmp/flake
cd /tmp/flake
sudo ./backup.sh open
sudo ./backup.sh restore
sudo ./backup.sh close
```

`restore` never deletes, and chowns the result to the account implied by the
target path. It also runs from the ISO — `rsync` ships on the installer, and
with no password store present `open` falls back to prompting for the pool
passphrase. See [backup.md](backup.md).

## First boot

Log in as the host's user with password `changeme`, then `passwd`.
