# trunkie: Arch → NixOS

Threadripper 1950X on an ASUS ROG Zenith Extreme (X399). Three M.2 sockets
total: one onboard under the PCH heatsink, two on the DIMM.2 riser.

## Target disk layout

| Role | Drive | Where |
|---|---|---|
| `root0` | Force MP500 224G | onboard M.2; carries the 1G ESP |
| `root1` | Intel SSDSC2CW240A3 224G | SATA |
| `home0` | ADATA SX8200 Pro 2048G | DIMM.2 slot 1 |
| `home1` | WD Black SN770 2000G | DIMM.2 slot 2 — replaces the WD SN550 931G |

Two btrfs RAID1 mirrors over LUKS: a root pair and a home pair. No swap;
trunkie does not hibernate.

The root pair is an exact sector match (`468862128` each). The home pair is
not — the ADATA is 2048 GB and the SN770 2000 GB, so the mirror caps at
1.82 TiB and ~45 GiB of the ADATA is unused. Harmless, but don't expect 1.86.

## Before the install

1. Pull the WD SN550 from DIMM.2 slot 2; fit the SN770.
2. Capture fresh by-id paths — the SN770's changes from `ata-*` to `nvme-*`
   once it leaves the USB enclosure:
   `ls -l /dev/disk/by-id/ | grep -vE 'part[0-9]+$'`
3. Unplug the backup dock. See [backup.md](backup.md).
4. Confirm `~/.gnupg` exists somewhere other than trunkie. It decrypts the
   password store, which holds the restic and LUKS passphrases. The store
   itself replicates via syncthing; the private key does not.

## Install

Build the ISO, write it to USB, boot it, then from `/iso/flake`:

```sh
./install.sh trunkie \
  --disk root0=<id> --disk root1=<id> \
  --disk home0=<id> --disk home1=<id>
```

All four names are required and are checked against
[../hosts/trunkie/disko-config.nix](../hosts/trunkie/disko-config.nix) before
anything is written.

## Backup state going in

- `~/backups` (417 GiB of old sebbers and triss machine images) → restic to OVH
  Beauharnois, deduped and compressed to 143 GiB.
- Full `/home` → the two-disk btrfs RAID1 pool, minus `.cache`.
- `~/*-repos` → also on roach.
- 23 syncthing folders → also on roach and sebbers.

## After

- Restore `/home` from the pool.
- Move both IronWolf 4TB drives from the dock onto internal SATA — five ports
  are free. The pool is found by partition label, so this needs no
  reconfiguration.
- Replace the pre-install rsync with `btrfs send`/`receive` (btrbk) now that
  both ends are btrfs, and declare the restic schedule in the flake.
