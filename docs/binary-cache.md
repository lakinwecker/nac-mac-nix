# Binary cache

trunkie builds once; every other host substitutes the result instead of
compiling it again. The cache lives on the SATA backup pool, not on trunkie's
root disk, and is reachable over the nebula mesh so roaming laptops get it from
anywhere.

**Status: planned, not implemented.** Open decisions are listed at the end.

## Does this pay off on spinning disks?

The drives are irrelevant to the answer. trunkie's link is 1000 Mb/s, so the
wire tops out near 112 MB/s. A ST4000VN006 sustains roughly 180–200 MB/s
sequential. The platter is already faster than the network; the cache would have
to move to 2.5 or 10 GbE before the spindle became the limit.

The time saved is compilation time, not transfer time, and that is unaffected by
what the bytes are stored on. Measured on trunkie's current store:

| class | paths | NAR size |
|-------|-------|----------|
| `.drv` files | 29713 | 0.12 GB |
| built here (`ultimate`) | 355 | 2.68 GB |
| signed by cache.nixos.org | 2110 | 22.35 GB |
| unsigned, non-`.drv` | 5406 | 27.01 GB |

The 2.68 GB built locally is the core win: transferring it costs about 25
seconds at gigabit, while rebuilding that same set on roach or a laptop costs
CPU-hours. Everything in that row is work another machine would otherwise
repeat.

The 22.35 GB signed by cache.nixos.org is a secondary and conditional win.
`attic push` sends the whole closure, so those paths land in the cache too and
clients pull them over the LAN instead of the internet. Whether that helps
depends entirely on how trunkie's WAN compares to gigabit — at 1 Gb symmetric it
is close to nothing, at 100–300 Mb it is the larger effect of the two. Measure
the WAN before counting on it.

Two things the cache does not do: it does not speed up trunkie itself, and it
does not help the first build of anything.

### RAID1 does not make reads faster

btrfs RAID1 does not stripe a read across both members. It selects one mirror
per read as `current->pid % num_stripes`, so a single client pulling a NAR is
served by a single drive. Concurrent readers on different threads land on
different mirrors and roughly double aggregate IOPS, but no individual transfer
is ever faster than one disk. The kernel here exposes only `[pid]` in
`/sys/fs/btrfs/<uuid>/read_policy`; `round-robin` is not compiled in, so there
is nothing to tune.

It would not help even if it did stripe. One drive sustains ~180–200 MB/s
against a ~112 MB/s wire — a single spindle already has more headroom than the
network can consume.

Page cache removes the disks from the common path regardless. trunkie has 62
GiB of RAM against a 2.68 GB locally-built set. The first host to pull a closure
warms it; every host after that is served from memory, which is exactly the
shape of the usual case where several machines pull the same update.

The RAID1 is worth having here for redundancy, not for throughput.

## Why attic

`services.atticd` keeps its own content-addressed, chunked, deduplicated store
and serves from that. Three properties decide it:

The cache stops being coupled to trunkie's `/nix/store`. trunkie can garbage
collect freely without emptying the cache, which is not true of anything that
serves the store directly.

It has a storage path that can point anywhere, so "500 GB on the pool" is a
configuration line rather than a filesystem migration.

It reads large chunk blobs rather than walking thousands of small files per
store path. On 7200rpm platters that difference is seek behaviour, which is the
one place the medium would otherwise show.

The cost is a database (SQLite is sufficient single-node), an RS256 token
secret, and an explicit push step — the cache holds what you send it, not
everything you happen to have built.

### Alternatives considered

`services.harmonia.cache` serves `/nix/store` over HTTP directly. Simpler: no
database, no token, no push step, and anything built is immediately available.
Rejected because the store it would serve sits on the WD SN550, which
`hosts/trunkie/disko-config.nix` deliberately leaves unmirrored on the grounds
that root is reproducible from the flake. That reasoning is sound for root and
wrong for a cache — a cache is the one thing on that disk that is not cheap to
reconstruct. Serving from the store also means never garbage collecting
anything you want to stay available, and a 500 GB volume on the pool would do
nothing for it short of relocating `/nix` onto SATA, which would put the build
store on platters.

`services.nix-serve` is the same serve-the-store model, older and less
maintained. harmonia supersedes it.

If the push step turns out to be the part that annoys, harmonia is the fallback
and the decision is worth revisiting — the client-side configuration is
identical either way.

## Storage

The pool is already btrfs RAID1 across `sda1`/`sdb1` over LUKS, built and driven
by `backup.sh` (see [backup.md](backup.md)). The cache gets a subvolume beside
the existing backup and snapshot subvolumes:

```
/mnt/backup/
├── lakin/          existing — rsync target
├── snapshots/      existing — read-only snapshots
└── nix-cache/      new — atticd storage.path
```

btrfs subvolumes have no intrinsic size, so 500 GB is a qgroup limit rather than
a partition. Repartitioning is not on the table: `sda1` and `sdb1` already span
their whole disks and carry the backups.

Because the pool is RAID1, a 500 GiB logical limit consumes about 1 TiB of raw
capacity across the pair.

Classic btrfs quotas slow down snapshot-heavy workloads, and this pool is
snapshot-heavy. Kernel 6.18 supports simple quotas (`btrfs quota enable
--simple`), which avoids most of that cost. Enabling quotas is a
filesystem-wide change that affects the backup subvolumes too, which makes it
one of the open decisions below.

### Keeping it mounted

`backup.sh open` unlocks and mounts on demand, which was right when the drives
lived in a USB dock. They are internal SATA now, and a cache needs the pool
mounted continuously. Two consequences:

Boot needs to unlock the pool without a prompt. trunkie's three existing LUKS
containers are unlocked interactively in the initrd; the pool is not among them
and should not be, because it is not needed to boot. A second LUKS keyslot with
a keyfile on the root filesystem is the fit — root is itself LUKS, unlocked
interactively at initrd, so the keyfile is protected at rest by the passphrase
you already type. The password-store entry stays the primary keyslot.

`./backup.sh close` will break the cache. It unmounts the pool, and atticd's
storage vanishes underneath it. Either the script grows an awareness of the
service or the habit has to change.

`services.btrfs.autoScrub.fileSystems` in `hosts/trunkie/default.nix` currently
lists `/` and `/home`. The pool mount belongs there once it is permanent.

## Server

trunkie only. `machines.nix` gains nothing; this is a host-level concern and
belongs in `hosts/trunkie/default.nix` or a module imported from it.

```nix
services.atticd = {
  enable = true;
  environmentFile = "/etc/atticd/env";   # see Secrets
  settings = {
    listen = "[::]:8080";
    storage = {
      type = "local";
      path = "/mnt/backup/nix-cache";
    };
  };
};
```

`database.url` defaults to `sqlite:///var/lib/atticd/server.db?mode=rwc`, which
is fine for one node. The module adds a `ReadWritePaths` entry automatically
when `storage.path` sits outside `/var/lib/atticd`, so pointing at the pool
needs no systemd hardening escape.

The unit must not start before the pool is mounted — a `RequiresMountsFor` on
the mount point, or an ordering dependency on the mount unit.

Firewall scope is the mesh, not the LAN and not the world:

```nix
networking.firewall.interfaces.nebula1.allowedTCPPorts = [ 8080 ];
```

## Clients

Every host already carries `nix.settings.substituters` and
`trusted-public-keys` in `common/user.nix`. The cache is appended there, using
trunkie's nebula address (`172.16.100.7`) rather than its LAN address, so
laptops off the home network still resolve it.

```nix
nix.settings.substituters = [
  "http://172.16.100.7:8080/nix-cache"     # ahead of upstream
  "https://cache.nixos.org"
  "https://hyprland.cachix.org"
];
nix.settings.trusted-public-keys = [ "nix-cache:…" ];   # from `attic cache info`
```

Substituter order matters: listing trunkie first is what makes it a LAN mirror
for upstream paths rather than a fallback nobody reaches.

Make the cache **public** (`attic cache configure --public`). Nix has no native
understanding of attic tokens — a private cache needs a token in each client's
`netrc`, which is five more secrets to distribute. Public plus a nebula-only
firewall puts the access control at the network layer, where the mesh already
enforces it.

An unreachable substituter costs latency on every client operation. Hosts that
are frequently away from the mesh want a low `connect-timeout` so a missing
trunkie degrades to a pause rather than a stall.

## Secrets

Two new secrets, neither of which belongs in the flake:

`ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64` — generated with
`openssl genrsa -traditional 4096 | base64 -w0`, delivered through
`services.atticd.environmentFile`. The repo has no secrets mechanism yet, so
this is a file placed by hand on trunkie, referenced by path.

The LUKS keyfile for pool auto-unlock, likewise placed by hand.

Both should be recorded in the password store alongside the existing
`lakin.ca/luks/trunkie-backup-pool` entry.

## Open decisions

1. **Quota or no quota.** A 500 GB qgroup limit is what was asked for, but it
   enables quotas across the whole pool including the backup subvolumes. The
   alternative is an unbounded subvolume plus monitoring. Simple quotas make
   the cost small but not zero.

2. **Push trigger.** A `post-build-hook` pushes automatically on every build and
   makes attic behave like harmonia. A manual `attic push` after a rebuild is
   less magic and less surprising. The hook is the reason to prefer attic over
   harmonia at all; without it the push step is pure overhead.

3. **What gets pushed.** Full closures make trunkie a LAN mirror for
   cache.nixos.org paths as well, at the cost of most of the 500 GB. Pushing
   only locally-built paths keeps the cache small and gives up the mirror
   effect. This is the WAN-speed question from the top of this document.

4. **`backup.sh close`.** Needs to either stop atticd first or refuse while the
   service is running.

5. **Retention.** attic has its own garbage collection. Nothing here has decided
   what expires or when.

## Rollout order

1. Measure trunkie's WAN throughput — it decides open question 3.
2. Add the LUKS keyfile keyslot; confirm the pool unlocks unattended.
3. Mount the pool at boot; add it to `autoScrub`.
4. Create the `nix-cache` subvolume; decide the quota question.
5. Generate the RS256 secret; bring up atticd on trunkie alone.
6. Create the cache, make it public, record the public key.
7. Push one closure by hand; pull it from roach with `--substituters` on the
   command line before touching `common/user.nix`.
8. Only then add the substituter to every host.

Step 7 is the one that catches a wrong public key or a firewall gap while it
still affects one machine instead of seven.
