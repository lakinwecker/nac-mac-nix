#!/usr/bin/env bash
# Manages the backup pool: a two-disk btrfs RAID1 mirror over LUKS, plus the
# restic repository that mirrors it offsite to OVH object storage.
#
# The pool is built once with `init` and thereafter located by GPT partition
# label, so it opens the same way whether the disks are in a USB dock or on
# internal SATA. Moving them between the two needs no reconfiguration.
#
# Usage:
#   ./backup.sh init --disk0 <disk-id> --disk1 <disk-id>   # DESTRUCTIVE
#   ./backup.sh open | close | status
#   ./backup.sh sync [--dry-run] [<source>]
#   ./backup.sh verify [<source>]
#   ./backup.sh snapshot [<name>]
#   ./backup.sh scrub [--wait]
#   ./backup.sh restic <args...>
#
# Secrets are read from the password store at call time and never written to
# disk. Nothing here stores a credential.
set -euo pipefail

# ── Pool identity ────────────────────────────────────────────────────
# Partition labels are the pool's identity. by-id paths change when the
# disks move between the dock and internal SATA; partition labels do not.
PART0=${PART0:-backup0}
PART1=${PART1:-backup1}
POOL_LABEL=${POOL_LABEL:-backup}
POOL_MOUNT=${POOL_MOUNT:-/mnt/backup}
SUBVOL=${SUBVOL:-trunkie-home}
SYNC_SOURCE=${SYNC_SOURCE:-/home/lakin}

# Skipped by `sync`. These are re-derivable and they churn while rsync reads
# them, which costs far more in seek time than they are worth: a browser cache
# is hundreds of thousands of tiny files that rewrite themselves mid-copy.
# Override with SYNC_EXCLUDES, or add one-offs with --exclude.
read -r -a SYNC_EXCLUDES <<<"${SYNC_EXCLUDES:-.cache/ .local/share/Trash/}"

# ── Password-store entries ───────────────────────────────────────────
PASS_LUKS=${PASS_LUKS:-lakin.ca/luks/trunkie-backup-pool}
PASS_S3_KEY=${PASS_S3_KEY:-lakin.ca/ovh/s3-backups/access-key}
PASS_S3_SECRET=${PASS_S3_SECRET:-lakin.ca/ovh/s3-backups/secret-key}
PASS_RESTIC=${PASS_RESTIC:-lakin.ca/restic/trunkie-backups}

# ── OVH object storage ───────────────────────────────────────────────
RESTIC_REPO=${RESTIC_REPO:-s3:https://s3.bhs.io.cloud.ovh.net/fretful-lehr/restic}
OVH_REGION=${OVH_REGION:-bhs}

usage() {
  cat >&2 <<EOF
Usage: $0 <command> [args...]

Pool lifecycle:
  init --disk0 <id> --disk1 <id>
        Partition, encrypt, and build a btrfs RAID1 mirror across two disks.
        DESTROYS both. <id> is a /dev/disk/by-id/... path; prefer the ata-*
        form, which follows the drive rather than the dock bay.
  open  Unlock both members and mount the pool at $POOL_MOUNT.
  close Unmount and lock. Run before unplugging the dock.

Data:
  sync [--dry-run] [--exclude <pattern>]... [<source>]
        rsync <source> into the pool's $SUBVOL subvolume.
        Source defaults to $SYNC_SOURCE.
        Always excluded: ${SYNC_EXCLUDES[*]}
  restore [--dry-run] [--mirror] [--owner <user:group>] [--no-chown]
          [--exclude <pattern>]... [<target>]
        rsync the pool's $SUBVOL subvolume back out onto <target>.
        Target defaults to $SYNC_SOURCE, and may be a subtree of it.
        Never deletes unless --mirror is given. Afterwards chowns the
        target to the user implied by $SYNC_SOURCE, because the pool
        stores the old system's numeric uids.
  verify [--exclude <pattern>]... [<source>]
        Compare <source> against the pool by content hash, writing nothing.
        Lists every file whose bytes differ or that never arrived. Clean
        output means the copy is byte-for-byte correct.
        <source> may be a subtree of $SYNC_SOURCE, which is compared against
        the matching place in the pool -- useful for checking the data you
        care about without reading everything.
  snapshot [<name>]
        Take a read-only btrfs snapshot of $SUBVOL.
        Name defaults to ${SUBVOL}-<timestamp>.

Integrity:
  status        Show pool membership, usage, and last scrub result.
  scrub [--wait]
        Start a btrfs scrub. Verifies every checksum and repairs from the
        mirror where it can. --wait blocks until it finishes.

Offsite:
  restic <args...>
        Run restic against the OVH repository with credentials injected
        from the password store. e.g. $0 restic snapshots

Environment overrides: PART0 PART1 POOL_LABEL POOL_MOUNT SUBVOL SYNC_SOURCE
                       PASS_LUKS PASS_S3_KEY PASS_S3_SECRET PASS_RESTIC
                       RESTIC_REPO OVH_REGION
EOF
  exit 1
}

# ── Helpers ──────────────────────────────────────────────────────────

# lwpass is a fish abbreviation, so it is absent from a bash script's PATH.
# Prefer a real binary if one ever appears; then bare pass; then let fish
# resolve the abbreviation. Last resort is typing it: on a live ISO there is
# no password store at all, because the store lives in the /home this script
# is being used to restore.
#
# Command substitution strips the trailing newline, which matters: the LUKS
# passphrase is the bare string, so a piped secret must match a typed one.
secret() {
  # Each attempt runs at most once: a second `pass show` to test for the entry
  # would ask gpg-agent for the key twice.
  local out=""
  if command -v lwpass >/dev/null 2>&1; then
    out=$(lwpass show "$1" 2>/dev/null) || out=""
  fi
  if [ -z "$out" ] && command -v pass >/dev/null 2>&1; then
    out=$(pass show "$1" 2>/dev/null) || out=""
  fi
  if [ -z "$out" ] && command -v fish >/dev/null 2>&1; then
    out=$(fish -c "lwpass show $1" 2>/dev/null) || out=""
  fi
  if [ -z "$out" ] && [ -t 0 ]; then
    echo "No password store entry for '$1'." >&2
    read -r -s -p "Enter it manually: " out
    echo >&2
  fi
  [ -n "$out" ] || { echo "ERROR: password store entry '$1' is empty or missing." >&2; exit 1; }
  printf '%s' "$out"
}

part_dev() { echo "/dev/disk/by-partlabel/$1"; }

# The physical disks behind the pool, e.g. "sdb". Used to measure read
# throughput during verify; /proc/diskstats is keyed by disk name.
pool_backing_disks() {
  local label dev disk
  for label in "$PART0" "$PART1"; do
    dev=$(readlink -f "$(part_dev "$label")" 2>/dev/null) || continue
    disk=$(lsblk -no PKNAME "$dev" 2>/dev/null | head -n1)
    [ -n "$disk" ] && echo "$disk"
  done
}

pool_sectors_read() {
  local re
  re=$(pool_backing_disks | paste -sd'|' -)
  [ -n "$re" ] || { echo 0; return; }
  awk -v re="^($re)\$" '$3 ~ re { r += $6 } END { print r+0 }' /proc/diskstats
}

# Checked before any destructive work. A tool missing halfway through would
# leave one disk partitioned and the other untouched.
require_cmds() {
  local missing=() c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  [ ${#missing[@]} -eq 0 ] && return 0

  echo "ERROR: missing required command(s): ${missing[*]}" >&2
  local pkgs=() m
  for m in "${missing[@]}"; do
    case "$m" in
      sgdisk)            pkgs+=(gptfdisk) ;;
      btrfs|mkfs.btrfs)  pkgs+=(btrfs-progs) ;;
      cryptsetup)        pkgs+=(cryptsetup) ;;
      *)                 pkgs+=("$m") ;;
    esac
  done
  # De-duplicate: mkfs.btrfs and btrfs both come from btrfs-progs.
  local uniq
  uniq=$(printf '%s\n' "${pkgs[@]}" | sort -u | tr '\n' ' ')
  echo "  Arch:   sudo pacman -S --needed $uniq" >&2
  echo "  NixOS:  add to environment.systemPackages" >&2
  exit 1
}

# Maps a source path to the matching location inside the pool, so a subtree
# can be synced or verified on its own: /home/lakin/backups compares against
# <pool>/trunkie-home/backups rather than against the subvolume root.
pool_dest() {
  local src="${1%/}" base="${SYNC_SOURCE%/}" rel
  if [ "$src" = "$base" ]; then
    echo "$POOL_MOUNT/$SUBVOL"
    return
  fi
  case "$src/" in
    "$base"/*) rel="${src#"$base"/}"; echo "$POOL_MOUNT/$SUBVOL/$rel" ;;
    *) echo "ERROR: $src is not under $base; cannot place it in the pool." >&2
       exit 1 ;;
  esac
}

require_open() {
  mountpoint -q "$POOL_MOUNT" || {
    echo "ERROR: pool is not mounted at $POOL_MOUNT. Run '$0 open' first." >&2
    exit 1
  }
}

# ── init ─────────────────────────────────────────────────────────────

cmd_init() {
  require_cmds sgdisk cryptsetup mkfs.btrfs btrfs

  local disk0="" disk1=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --disk0) [ $# -ge 2 ] || usage; disk0="$2"; shift 2 ;;
      --disk1) [ $# -ge 2 ] || usage; disk1="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; usage ;;
    esac
  done
  [ -n "$disk0" ] && [ -n "$disk1" ] || { echo "ERROR: both --disk0 and --disk1 are required." >&2; usage; }

  local real0 real1
  real0=$(readlink -f "$disk0") || { echo "ERROR: $disk0 not found." >&2; exit 1; }
  real1=$(readlink -f "$disk1") || { echo "ERROR: $disk1 not found." >&2; exit 1; }
  [ -b "$real0" ] || { echo "ERROR: $disk0 is not a block device." >&2; exit 1; }
  [ -b "$real1" ] || { echo "ERROR: $disk1 is not a block device." >&2; exit 1; }
  [ "$real0" != "$real1" ] || { echo "ERROR: --disk0 and --disk1 are the same device." >&2; exit 1; }

  echo "This will DESTROY all data on both disks:"
  printf '  disk0  %s -> %s  (%s)\n' "$disk0" "$real0" "$(lsblk -dno SIZE,MODEL "$real0")"
  printf '  disk1  %s -> %s  (%s)\n' "$disk1" "$real1" "$(lsblk -dno SIZE,MODEL "$real1")"
  echo
  read -r -p "Type 'WIPE' to continue: " confirm
  [ "$confirm" = "WIPE" ] || { echo "Aborted."; exit 1; }

  echo
  echo "==> Partitioning"
  # The partition must be a whole number of 4096-byte sectors or LUKS refuses
  # --sector-size 4096. Running to the last usable sector does not give that:
  # GPT reserves an odd tail, so `-n 1:0:0` leaves a size indivisible by 8.
  # Round the end down to an 8-sector boundary instead, costing at most 3.5 KiB.
  local start=2048
  for spec in "$real0:$PART0" "$real1:$PART1"; do
    local dev="${spec%:*}" label="${spec##*:}" last end
    sudo sgdisk --zap-all "$dev"
    # sgdisk -E prints chatter alongside the sector number ("Creating new GPT
    # entries in memory." on a freshly zapped disk), so take the last bare
    # numeric line rather than the whole output.
    last=$(sudo sgdisk -E "$dev" | grep -oE '^[0-9]+$' | tail -n1)
    [[ "$last" =~ ^[0-9]+$ ]] || {
      echo "ERROR: could not read last usable sector of $dev." >&2; exit 1; }
    end=$(( start + ((last - start + 1) / 8) * 8 - 1 ))
    sudo sgdisk -n "1:$start:$end" -t 1:8300 -c "1:$label" "$dev"
  done
  sudo udevadm settle

  echo
  echo "==> Encrypting (LUKS2, 4096-byte sectors to match the disks)"
  local pass
  pass=$(secret "$PASS_LUKS")
  for label in "$PART0" "$PART1"; do
    printf '%s' "$pass" | sudo cryptsetup luksFormat \
      --type luks2 --sector-size 4096 --batch-mode --key-file - "$(part_dev "$label")"
  done
  for label in "$PART0" "$PART1"; do
    printf '%s' "$pass" | sudo cryptsetup open --key-file - "$(part_dev "$label")" "$label"
  done
  unset pass

  echo
  echo "==> Creating btrfs RAID1 mirror"
  sudo mkfs.btrfs -L "$POOL_LABEL" -d raid1 -m raid1 \
    "/dev/mapper/$PART0" "/dev/mapper/$PART1"

  echo
  echo "==> Creating subvolumes"
  sudo mkdir -p "$POOL_MOUNT"
  sudo mount -o compress=zstd:3,noatime "/dev/mapper/$PART0" "$POOL_MOUNT"
  sudo btrfs subvolume create "$POOL_MOUNT/$SUBVOL"
  sudo btrfs subvolume create "$POOL_MOUNT/snapshots"

  echo
  echo "Pool ready at $POOL_MOUNT"
  cmd_status
}

# ── open / close ─────────────────────────────────────────────────────

cmd_open() {
  require_cmds cryptsetup btrfs

  if mountpoint -q "$POOL_MOUNT"; then
    echo "Already mounted at $POOL_MOUNT."
    return 0
  fi

  local pass label
  for label in "$PART0" "$PART1"; do
    [ -e "$(part_dev "$label")" ] || {
      echo "ERROR: partition '$label' not present. Is the dock plugged in?" >&2
      exit 1
    }
  done

  pass=$(secret "$PASS_LUKS")
  for label in "$PART0" "$PART1"; do
    if [ -e "/dev/mapper/$label" ]; then
      echo "  $label already unlocked"
    else
      printf '%s' "$pass" | sudo cryptsetup open --key-file - "$(part_dev "$label")" "$label"
    fi
  done
  unset pass

  # Both members must be visible before btrfs will mount a RAID1 pool.
  sudo btrfs device scan >/dev/null
  sudo mkdir -p "$POOL_MOUNT"
  sudo mount -o compress=zstd:3,noatime "/dev/mapper/$PART0" "$POOL_MOUNT"
  echo "Mounted at $POOL_MOUNT"
}

cmd_close() {
  require_cmds cryptsetup

  if mountpoint -q "$POOL_MOUNT"; then
    sudo umount "$POOL_MOUNT"
    echo "Unmounted $POOL_MOUNT"
  fi
  local label
  for label in "$PART1" "$PART0"; do
    if [ -e "/dev/mapper/$label" ]; then
      sudo cryptsetup close "$label"
      echo "Locked $label"
    fi
  done
  echo "Safe to unplug."
}

# ── status ───────────────────────────────────────────────────────────

cmd_status() {
  require_cmds btrfs

  if ! mountpoint -q "$POOL_MOUNT"; then
    echo "Pool: not mounted"
    local label
    for label in "$PART0" "$PART1"; do
      if [ -e "$(part_dev "$label")" ]; then
        echo "  $label present   ($(readlink -f "$(part_dev "$label")"))"
      else
        echo "  $label MISSING"
      fi
    done
    return 0
  fi

  echo "Pool: mounted at $POOL_MOUNT"
  echo
  sudo btrfs filesystem show "$POOL_MOUNT"
  echo
  sudo btrfs filesystem usage "$POOL_MOUNT" | head -12
  echo
  echo "Subvolumes:"
  sudo btrfs subvolume list "$POOL_MOUNT" | sed 's/^/  /'
  echo
  echo "Scrub:"
  sudo btrfs scrub status "$POOL_MOUNT" | sed 's/^/  /'
}

# ── sync ─────────────────────────────────────────────────────────────

cmd_sync() {
  require_cmds rsync

  local dry=false src="" extra=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run|-n) dry=true; shift ;;
      --exclude) [ $# -ge 2 ] || usage; extra+=("$2"); shift 2 ;;
      -*) echo "Unknown option: $1" >&2; usage ;;
      *) src="$1"; shift ;;
    esac
  done
  src="${src:-$SYNC_SOURCE}"
  [ -d "$src" ] || { echo "ERROR: source $src is not a directory." >&2; exit 1; }

  require_open

  # --numeric-ids keeps ownership correct across a reinstall, where the
  # rebuilt system may not have the same name-to-uid mapping.
  #
  # --delete-during, not --delete-after: the latter needs the complete file
  # list before it can transfer anything, which on a multi-million-file home
  # means many minutes of silence. Deleting as we go keeps rsync's incremental
  # recursion, so work starts immediately.
  #
  # --partial keeps a half-sent large file across an interruption; this run
  # takes hours and Steam holds some very big ones.
  local args=(-aHAX --numeric-ids --info=progress2 --delete-during --partial)
  local pat
  for pat in ${SYNC_EXCLUDES+"${SYNC_EXCLUDES[@]}"} ${extra+"${extra[@]}"}; do
    args+=(--exclude "$pat")
  done
  $dry && args+=(--dry-run)

  local dest; dest=$(pool_dest "$src")
  sudo mkdir -p "$dest"

  echo "==> rsync ${src%/}/ -> $dest/"
  $dry && echo "    (dry run)"

  # Exit 24 means source files disappeared mid-run. On a live home directory
  # that is normal -- browser caches rewrite themselves constantly -- and it
  # is not a failure. Anything else is.
  local rc=0
  sudo rsync "${args[@]}" "${src%/}/" "$dest/" || rc=$?
  case "$rc" in
    0)  echo "Sync complete." ;;
    24) echo "Sync complete. Some source files vanished mid-run (rsync 24);" \
             "normal for a live home directory." ;;
    *)  echo "ERROR: rsync failed with exit $rc." >&2; exit "$rc" ;;
  esac
}

# ── restore ──────────────────────────────────────────────────────────

# The reverse of sync: pool -> target. Deliberately never deletes. sync's
# --delete-during is correct for a mirror, but on a restore the extra files
# are whatever the freshly installed system already put there, and deleting
# them is not what "restore my home" means. Use --mirror to opt in.
cmd_restore() {
  require_cmds rsync

  local dry=false mirror=false target="" owner="" extra=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run|-n) dry=true; shift ;;
      --mirror) mirror=true; shift ;;
      --owner) [ $# -ge 2 ] || usage; owner="$2"; shift 2 ;;
      --no-chown) owner="-"; shift ;;
      --exclude) [ $# -ge 2 ] || usage; extra+=("$2"); shift 2 ;;
      -*) echo "Unknown option: $1" >&2; usage ;;
      *) target="$1"; shift ;;
    esac
  done
  target="${target:-$SYNC_SOURCE}"

  require_open

  # pool_dest maps a path under SYNC_SOURCE to its place in the pool. Here it
  # names the source rather than the destination, which is what makes subtree
  # restores work: /home/lakin/backups pulls from <pool>/trunkie-home/backups.
  local src; src=$(pool_dest "$target")
  [ -d "$src" ] || {
    echo "ERROR: $src does not exist in the pool. Nothing to restore from." >&2
    exit 1
  }

  # --numeric-ids preserves the uid/gid the files were saved with. Those are
  # the old system's, so the chown below is what actually makes the restored
  # files belong to the new account.
  local args=(-aHAX --numeric-ids --info=progress2 --partial)
  local pat
  for pat in ${extra+"${extra[@]}"}; do
    args+=(--exclude "$pat")
  done
  $mirror && args+=(--delete-during)
  $dry && args+=(--dry-run)

  echo "==> rsync $src/ -> ${target%/}/"
  $dry && echo "    (dry run)"
  $mirror && echo "    (--mirror: files not in the pool will be DELETED)"

  sudo mkdir -p "${target%/}"
  sudo rsync "${args[@]}" "$src/" "${target%/}/"

  # Default to the owner implied by the path: /home/lakin -> lakin:users.
  # NixOS need not have handed the rebuilt account the same uid Arch did.
  if [ "$owner" = "-" ]; then
    echo "Restore complete. Ownership left as stored (--no-chown)."
  else
    [ -n "$owner" ] || owner="$(basename "${SYNC_SOURCE%/}"):users"
    if $dry; then
      echo "Restore complete (dry run). Would chown -R $owner ${target%/}"
    else
      echo "==> chown -R $owner ${target%/}"
      sudo chown -R "$owner" "${target%/}"
      echo "Restore complete."
    fi
  fi
}

# ── verify ───────────────────────────────────────────────────────────

cmd_verify() {
  require_cmds rsync

  local src="" extra=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --exclude) [ $# -ge 2 ] || usage; extra+=("$2"); shift 2 ;;
      -*) echo "Unknown option: $1" >&2; usage ;;
      *) src="$1"; shift ;;
    esac
  done
  src="${src:-$SYNC_SOURCE}"
  [ -d "$src" ] || { echo "ERROR: source $src is not a directory." >&2; exit 1; }

  require_open

  # --checksum compares content hashes instead of size and mtime. That is the
  # entire point: a file whose bytes were corrupted in transit keeps its size
  # and mtime, so the default quick check would call it identical. -n writes
  # nothing, so this is safe to run against a pool you are relying on.
  local args=(-aHAXn --checksum --numeric-ids --out-format=%n)
  local pat
  for pat in ${SYNC_EXCLUDES+"${SYNC_EXCLUDES[@]}"} ${extra+"${extra[@]}"}; do
    args+=(--exclude "$pat")
  done

  local dest; dest=$(pool_dest "$src")
  [ -d "$dest" ] || { echo "ERROR: $dest does not exist in the pool." >&2; exit 1; }

  local log diffs_log rc=0
  log=$(mktemp -t backup-verify-XXXXXX.log)
  diffs_log="${log%.log}-diffs.log"

  echo "==> Comparing ${src%/}/ against $dest/ by content hash"
  echo "    Reads both sides in full; expect hours for a whole home directory."
  echo "    Differing files print as they are found -- a quiet run is a clean one."
  echo

  # rsync's own --info=progress2 counts *transferred* bytes, which in a dry
  # run stay near zero however far along it is. Report bytes read off the
  # pool instead: that is the work actually being done. It goes to stderr so
  # it stays out of the tee'd log.
  local start_sectors start_time total_gib
  start_sectors=$(pool_sectors_read)
  start_time=$(date +%s)
  total_gib=$(df --output=used -k "$POOL_MOUNT" 2>/dev/null | tail -n1 \
              | awk '{printf "%.0f", $1/1048576}')

  (
    while :; do
      sleep 20
      sectors=$(( $(pool_sectors_read) - start_sectors ))
      elapsed=$(( $(date +%s) - start_time ))
      [ "$elapsed" -gt 0 ] || continue
      awk -v s="$sectors" -v e="$elapsed" -v t="${total_gib:-0}" 'BEGIN {
        gib  = s * 512 / 1073741824
        rate = s * 512 / e / 1048576
        if (t > 0)
          printf "\r  read %.1f / ~%d GiB (%d%%)  %.0f MiB/s  elapsed %dm      ",
                 gib, t, gib * 100 / t, rate, e / 60
        else
          printf "\r  read %.1f GiB  %.0f MiB/s  elapsed %dm      ", gib, rate, e / 60
      }' >&2
    done
  ) &
  local monitor=$!

  # set +e because pipefail would otherwise abort on rsync's exit 24, and
  # because the status wanted is rsync's, not tee's.
  set +e
  sudo rsync "${args[@]}" "${src%/}/" "$dest/" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e

  kill "$monitor" 2>/dev/null || true
  wait "$monitor" 2>/dev/null || true
  printf '\r%*s\r' 78 '' >&2

  # Directory entries always appear in the output; only files matter here.
  grep -ve '/$' -e '^$' "$log" > "$diffs_log" || true
  local diffs
  diffs=$(wc -l < "$diffs_log")

  echo
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 24 ]; then
    echo "ERROR: rsync failed with exit $rc. See $log" >&2
    exit "$rc"
  fi
  if [ "$diffs" -eq 0 ]; then
    echo "OK: every file matches by content hash."
    rm -f "$log" "$diffs_log"
  else
    echo "MISMATCH: $diffs file(s) differ or are missing from the pool."
    echo "Full list: $diffs_log"
    echo
    head -20 "$diffs_log" | sed 's/^/  /'
    [ "$diffs" -gt 20 ] && echo "  ... $((diffs - 20)) more"
    exit 1
  fi
}

# ── snapshot ─────────────────────────────────────────────────────────

cmd_snapshot() {
  require_cmds btrfs
  require_open
  local name="${1:-$SUBVOL-$(date +%Y%m%d-%H%M%S)}"
  local dest="$POOL_MOUNT/snapshots/$name"
  [ -e "$dest" ] && { echo "ERROR: snapshot $name already exists." >&2; exit 1; }

  # Read-only, so nothing that happens to the live subvolume later can
  # reach through it. That is what separates a snapshot from a copy.
  sudo btrfs subvolume snapshot -r "$POOL_MOUNT/$SUBVOL" "$dest"
  echo "Snapshot: $dest"
}

# ── scrub ────────────────────────────────────────────────────────────

cmd_scrub() {
  require_cmds btrfs
  require_open
  local wait=false
  [ "${1:-}" = "--wait" ] && wait=true

  if $wait; then
    sudo btrfs scrub start -B "$POOL_MOUNT"
  else
    sudo btrfs scrub start "$POOL_MOUNT"
    echo "Started. Check with: $0 status"
  fi
}

# ── restic ───────────────────────────────────────────────────────────

cmd_restic() {
  require_cmds restic
  [ $# -gt 0 ] || { echo "ERROR: restic needs arguments, e.g. '$0 restic snapshots'." >&2; exit 1; }

  AWS_ACCESS_KEY_ID=$(secret "$PASS_S3_KEY") \
  AWS_SECRET_ACCESS_KEY=$(secret "$PASS_S3_SECRET") \
  AWS_DEFAULT_REGION="$OVH_REGION" \
  RESTIC_REPOSITORY="$RESTIC_REPO" \
  RESTIC_PASSWORD=$(secret "$PASS_RESTIC") \
  RESTIC_COMPRESSION="${RESTIC_COMPRESSION:-max}" \
    restic "$@"
}

# ── dispatch ─────────────────────────────────────────────────────────

[ $# -ge 1 ] || usage
cmd="$1"; shift

case "$cmd" in
  init)     cmd_init "$@" ;;
  open)     cmd_open "$@" ;;
  close)    cmd_close "$@" ;;
  status)   cmd_status "$@" ;;
  sync)     cmd_sync "$@" ;;
  restore)  cmd_restore "$@" ;;
  verify)   cmd_verify "$@" ;;
  snapshot) cmd_snapshot "$@" ;;
  scrub)    cmd_scrub "$@" ;;
  restic)   cmd_restic "$@" ;;
  -h|--help|help) usage ;;
  *) echo "Unknown command: $cmd" >&2; usage ;;
esac
