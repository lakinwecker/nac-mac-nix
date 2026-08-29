# trunkie: Arch → NixOS

Threadripper 1950X on an ASUS ROG Zenith Extreme (X399). Three M.2 sockets
total: one onboard under the PCH heatsink, two on the DIMM.2 riser. Six SATA
ports, two of them now carrying the backup pool.

## Target disk layout

| Role | Drive | Where |
|---|---|---|
| `root` | WD SN550 931G (`WDC WDS100T2B0C-00PXH0`) | onboard M.2; carries the 1G ESP |
| `home0` | ADATA SX8200 Pro 1.9T | DIMM.2 slot 1 |
| `home1` | WD Black SN770 1.8T | DIMM.2 slot 2 |

Root is a single LUKS-encrypted btrfs volume with subvolumes `/` and `/nix`.
Home is a btrfs RAID1 mirror across two LUKS members. No swap; trunkie does not
hibernate.

### Why root is not mirrored

The original plan paired a Force MP500 224G with an Intel SSDSC2CW240A3 224G as
a root mirror. That mirror caps at the smaller member, so it bought 224G of
redundant root at the cost of an M.2 socket and a SATA port. On NixOS the root
filesystem is reproducible from this flake — a root disk failure costs a
reinstall, not data — so the redundancy is worth much less than it was under
Arch. Dropping it frees the socket for the SN550, giving 931G of root for `/nix`
to grow into.

Both 224G drives are now out of the machine. The MP500 is in a USB enclosure
and still holds the old Arch root (550M ESP, 223G LUKS, 1007K BIOS boot).
Nothing on it is backed up — only `/home` ever was. Pull anything wanted from
`/etc` or `/var/lib` before reusing it.

The home pair is not an exact size match — the ADATA is 1.9T and the SN770
1.8T — so the mirror caps at the smaller and roughly 45 GiB of the ADATA goes
unused. Harmless, but don't expect the full 1.9.

## Before the install

1. Rebuild the ISO. The installer carries a copy of this flake at `/iso/flake`,
   baked in at build time via `isoImage.contents`, so the three-disk
   `hosts/trunkie/disko-config.nix` only reaches the installer through a fresh
   ISO. See [build.md](build.md).
2. Fix networking on the live ISO. `disko-install` runs `nixos-install`, which
   must evaluate `.#trunkie` and fetch its closure; the ISO ships the flake
   source but not its inputs, so the install cannot run offline. The board has
   two wired NICs — an Intel I211 (`igb`) and an Aquantia AQC107 10G
   (`atlantic`, needs firmware). Try the I211 port first, then check
   `nmcli device status` and `ping -c2 cache.nixos.org`.
3. Confirm the pool copy of `/home` is current: `./backup.sh open` then
   `./backup.sh verify`. See [backup.md](backup.md).
4. Confirm nothing is wanted from the SN550's existing NTFS partition — the
   install wipes it.
5. Confirm `~/.gnupg` exists somewhere other than trunkie. It decrypts the
   password store, which holds the restic and LUKS passphrases. The store
   itself replicates via syncthing; the private key does not.

## Install

Boot the rebuilt ISO, then from `/iso/flake`:

```sh
./install.sh trunkie \
  --disk root=/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_2042E2801181 \
  --disk home0=/dev/disk/by-id/nvme-ADATA_SX8200PNP_2L272L19EGUD \
  --disk home1=/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_23090Q800080
```

All three names are required and are checked against
[../hosts/trunkie/disko-config.nix](../hosts/trunkie/disko-config.nix) before
anything is written. Re-check the by-id paths against `ls /dev/disk/by-id/`
before running — the serials above are the ones observed, but the two IronWolf
`ata-ST4000VN006-3CW104_*` entries must never appear in this command.

The installer prompts once for a LUKS passphrase and uses it for all three
containers.

## Restoring /home

`backup.sh` is not on the freshly installed system. It lives in this flake,
which lives in `/home/lakin/personal-repos` — the thing being restored. Cloning
it is no help either: the git remote is SSH, and the key is in the same
unrestored home. **Leave the installer USB plugged in through the first reboot**;
the ISO carries the flake at `/flake` on its filesystem.

From a TTY on the freshly installed system, after the first boot but before
logging into the desktop, so nothing has written into `~/.config` yet:

```nu
lsblk -o NAME,SIZE,LABEL,FSTYPE
sudo mkdir -p /mnt/usb
sudo mount -o ro /dev/sdX1 /mnt/usb
cp -r /mnt/usb/flake /tmp/flake
cd /tmp/flake
sudo ./backup.sh open
sudo ./backup.sh restore
sudo ./backup.sh close
```

`open` prompts for the pool passphrase rather than failing — there is no
password store on the machine yet. Have it to hand from another machine.

`restore` never deletes, and chowns `/home/lakin` to `lakin:users` afterwards —
the pool holds Arch's numeric uids, which need not match what NixOS assigns.
There is no password store on the machine yet, so `open` will prompt for the
pool passphrase; have it to hand from another machine.

Doing it from the ISO before first boot also works, but `install.sh` unmounts
`/mnt` and closes the LUKS containers when it finishes, so the target has to be
remounted (`disko --mode mount`) first. Not worth it unless the first boot
fails.

## Backup state going in

- `~/backups` (417 GiB of old sebbers and triss machine images) → restic to OVH
  Beauharnois, deduped and compressed to 143 GiB.
- Full `/home` → the two-disk btrfs RAID1 pool, minus `.cache`.
- `~/*-repos` → also on roach.
- 23 syncthing folders → also on roach and sebbers.

The pool now lives on internal SATA rather than the dock. It is found by
partition label (`backup0`, `backup1`), so the move needed no reconfiguration.

## Open items

- **Second monitor** does not come up on the live ISO. Deferred to after the
  install, where `hyprHostConfig` in `machines.nix` drives the KVM-shared
  HDMI-A-1 and the rotated DP-1.
- Replace the pre-install rsync with `btrfs send`/`receive` (btrbk) now that
  both ends are btrfs, and declare the restic schedule in the flake.
