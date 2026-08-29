# Backup

Two 4TB Seagate IronWolf drives (`ST4000VN006`) form a btrfs RAID1 mirror over
LUKS. `backup.sh` builds and drives it, and wraps the restic repository that
mirrors the pool offsite to OVH object storage in Beauharnois.

## Architecture

```
/home  ──rsync (pre-install) or btrfs send (after)──▶  backup pool
                                                        2x4TB btrfs RAID1
                                                        + read-only snapshots
                                                             │
                                                             │ restic
                                                             ▼
                                                        OVH BHS (offsite)
```

RAID1 protects against a drive dying, and because btrfs checksums every block
and holds a second copy, `scrub` **repairs** bit rot rather than merely
reporting it. Snapshots cover the case RAID1 cannot: a deletion or a bad sync
propagating to both members instantly. Neither covers fire or theft, which is
what the OVH copy is for.

## Identity, and moving between dock and SATA

The pool is located by **GPT partition label** (`backup0`, `backup1`), not by
device path. LUKS and btrfs both record their own UUIDs in the superblock, so a
pool built while the drives sit in a USB dock assembles unchanged when they move
to internal SATA. Nothing needs reconfiguring; `open` finds them either way.

The USB dock's `by-id` paths (`usb-…-0:0`, `-0:1`) encode the *dock's* serial
plus a bay number, so they identify the slot rather than the drive. Use the
`ata-ST4000VN006-…_<serial>` form for `init`, which follows the drive itself and
stays correct after the move.

## First build

Destructive. Both disks are wiped.

```sh
./backup.sh init \
  --disk0 /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW64DDCC \
  --disk1 /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW64DD26
```

The LUKS passphrase comes from the password store entry named by `PASS_LUKS`.
Create it first, without ever displaying it:

```fish
openssl rand -base64 32 | tr -d '\n' | lwpass insert -m lakin.ca/luks/trunkie-backup-pool
```

LUKS is formatted with `--sector-size 4096` to match the drives' physical block
size — these are 512e disks, and the larger sector is a real throughput gain.

## Routine use

```sh
./backup.sh open              # unlock + mount at /mnt/backup
./backup.sh snapshot          # freeze the current state FIRST
./backup.sh sync              # rsync /home/lakin into the pool
./backup.sh restore           # rsync the pool back out onto /home/lakin
./backup.sh verify            # compare by content hash
./backup.sh status            # membership, usage, last scrub
./backup.sh close             # unmount + lock before unplugging
```

`.cache/` and `.local/share/Trash/` are excluded by default — re-derivable, and
they rewrite themselves while rsync reads them, which costs more in seek time
than they are worth. `SYNC_EXCLUDES` replaces that list; `--exclude` adds to it.

### verify

`sync` copies; it does not check what arrived. rsync compares size and mtime by
default, so a file whose bytes were corrupted in transit still looks identical.
`verify` re-reads both sides and compares content hashes:

```sh
./backup.sh verify
```

Clean output means byte-for-byte correct. Anything listed either differs or
never arrived, and the full list is written to a log it names. It reads
everything on both sides, so it is slow — run it after any sync you intend to
rely on, and always before wiping the source.

**Snapshot before sync, every time.** `sync` passes `--delete-during`, so
anything gone from the source is removed from the pool. That is correct for a
mirror, and the read-only snapshot taken beforehand is what makes it safe: a
mistaken deletion — or a sync pointed at the wrong source — is recoverable from
the snapshot rather than gone.

(`--delete-during` rather than `--delete-after` because the latter needs the
complete file list before transferring anything, which on a home directory of
several million files means many minutes of silence before work begins.)

Scrub monthly or after any unclean disconnect:

```sh
./backup.sh scrub --wait
```

## Offsite

`restic` is a passthrough wrapper that injects the OVH credentials and repo
password from the password store at call time. Nothing is written to disk and no
credential is stored in the repository.

```sh
./backup.sh restic snapshots
./backup.sh restic backup /mnt/backup/trunkie-home
./backup.sh restic check --read-data
./backup.sh restic prune
```

`RESTIC_COMPRESSION` defaults to `max`. On the sebbers/triss machine backups
that produced 41% deduplication and a further 1.73x compression — 417 GiB of
files stored as 143 GiB.

`check --read-data` downloads and re-hashes every pack. OVH charges no egress,
so a full verification costs time only; run it after any backup you intend to
rely on.

## During a reinstall

Physically unplug the dock before running `install.sh`. disko only touches disks
named in the host's config and `install.sh` passes explicit `--disk` paths, so
the pool is safe by construction — but a mistyped by-id path is precisely the
mistake that would eat it, and pulling one cable removes the possibility.

Now that the pool lives on internal SATA there is no cable to pull, so read the
`--disk` arguments back before confirming. The pool disks are the two
`ata-ST4000VN006-3CW104_*` entries; neither should ever appear.

### restore

The reverse of `sync`. Easiest after the first boot, from a TTY, before logging
into the desktop — nothing has written into `~/.config` yet:

```sh
sudo ./backup.sh open
sudo ./backup.sh restore
sudo ./backup.sh close
```

`restore` never deletes: the files it would delete are whatever the fresh
install just created, which is not what restoring a home directory means. Pass
`--mirror` to opt into `--delete-during`.

It then chowns the target — `/home/lakin` implies `lakin:users`. The pool stores
the old system's numeric uids, and a rebuilt system need not hand the account
the same one. `--owner user:group` overrides, `--no-chown` skips it.

Like `sync` and `verify`, the target may be a subtree: `restore
/home/lakin/backups` pulls only that directory, from the matching place in the
pool.

Running it from the live ISO also works — `rsync` ships on the installer, and
`install.sh` has to be re-run with `disko --mode mount` to get the target back
under `/mnt` first, since it unmounts everything when it finishes.

## Secrets

| Entry | Holds |
|---|---|
| `lakin.ca/luks/trunkie-backup-pool` | LUKS passphrase for both members |
| `lakin.ca/ovh/s3-backups/access-key` | OVH S3 access key |
| `lakin.ca/ovh/s3-backups/secret-key` | OVH S3 secret key |
| `lakin.ca/restic/trunkie-backups` | restic repository password |

Override the entry names with `PASS_LUKS`, `PASS_S3_KEY`, `PASS_S3_SECRET`, and
`PASS_RESTIC`.

Secrets are resolved by trying `lwpass`, then bare `pass`, then `lwpass` via
`fish`, and finally by prompting on the terminal. The prompt is what makes the
script usable from a live ISO, where there is no password store at all —
because the store lives in the `/home` being restored.

The restic password cannot be recovered or reset — losing it loses the offsite
repository. It is read from the password store, which is decrypted by a GPG
private key. **That key must exist somewhere other than the machine being
backed up.** The password store itself replicates via syncthing; `~/.gnupg` does
not.
