# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A flake-based set of NixOS configurations for the user's personal machines, plus matching live installer ISOs. The same flake produces both the bootable installer and the installed system for each machine.

Machines:
- **harry** — Surface Pro 9 (Intel)
- **sebbers** — AMD laptop
- **trunkie** — Threadripper desktop
- **roach** — Asus TUF Gaming F16 (Intel Raptor Lake + NVIDIA RTX)

## Build

```bash
# Build all installer ISOs
./build.sh

# Build a single ISO (harry | sebbers | trunkie | roach)
nix build .#nixosConfigurations.harry-iso.config.system.build.isoImage

# Build (don't install) an installed-system config to check evaluation
nix build .#nixosConfigurations.harry.config.system.build.toplevel
```

ISO output lands in `./result-<host>/iso/nixos-*.iso`. Write to USB with `dd`. Boot menu on SP9: hold Volume Down + Power.

## Install onto a machine

The installer ISO copies the flake to `/iso/flake`. From the live environment:

```bash
sudo disko-install --flake /iso/flake#harry --disk main /dev/disk/by-id/nvme-...
```

`disko-config.nix` defines the partition layout (512M EFI + LUKS btrfs with `/`, `/home`, `/nix` subvolumes). LUKS password is read from `/tmp/disk-password` at install time. `roach` uses a separate dual-drive layout in `hosts/roach/disko-config.nix`. See `INSTALL.md`.

## Architecture

`flake.nix` is a slim orchestrator (~200 lines) that composes modules and defines eight `nixosConfigurations` (4 hosts x {iso, installed}) via two helper functions (`mkIso`, `mkInstalled`).

### Directory layout

```
common/                  # Shared config, broken into broad themes
  default.nix            # imports all sub-modules + program directories
  networking.nix         # iwd, networkd, avahi, stevenblack, firewall, openssh,
                         #   polkit, gnupg, nebula, lan-mouse, syncthing
  desktop.nix            # fonts, dconf, qt theming, firefox extensions, graphics
  audio.nix              # bluetooth, pipewire, wireplumber, MPD
  packages.nix           # environment.systemPackages
  user.nix               # nix settings, shells, timezone, home dir activation

hosts/                   # One directory per machine — hardware-specific config
  harry/default.nix      # Surface Pro 9: kernel, initrd, power, hibernate, touchscreen
  sebbers/default.nix    # AMD laptop: amdgpu, TLP
  trunkie/default.nix    # Threadripper desktop: amdgpu
  roach/default.nix      # Asus TUF: NVIDIA, asusd, supergfxd, initrd, TLP
  roach/disko-config.nix # Dual-drive LUKS layout for roach

hypr/  ghostty/  nvim/   # Program-specific NixOS modules (imported by common/)
fish/  starship/  bin/  zellij/
```

### Module composition

- `commonModules = [ ./common ]` — imports `common/default.nix`, which pulls in all themed sub-modules plus program directories (`hypr/`, `ghostty/`, `nvim/`, etc.).
- Each host's module list adds `nixos-hardware` modules (flake inputs) + `./hosts/<name>`.
- `mkIso` and `mkInstalled` helper functions eliminate boilerplate for ISO and installed configs.

When adding a setting that should apply everywhere, put it in the appropriate `common/*.nix` file. When it's hardware-specific, put it in `hosts/<name>/default.nix`.

### Program directories

The directories `hypr/`, `nvim/`, `fish/`, etc. are NixOS modules — each exposes a `default.nix` that's imported by `common/default.nix`. Edit these to change desktop / editor / shell behavior across all hosts at once.

## harry (Surface Pro 9) specifics

- Kernel: `hardware.microsoft-surface.kernelVersion = "stable"`. ZFS is force-disabled — incompatible with the surface kernel. Rust kernel support is force-disabled via a kernel patch.
- Type Cover at the LUKS prompt requires the `pinctrl_tigerlake`, `intel_lpss*`, `surface_aggregator*`, `surface_hid*`, `hid_multitouch`, and `ithc` modules in `boot.initrd.kernelModules`. Don't remove these without testing the LUKS prompt.
- `surface_gpe` is blacklisted — it caused wake failures with the Type Cover closed during suspend.
- SP9 firmware only supports s2idle (no S3). `mem_sleep_default=s2idle` and `i915.enable_psr=0` in `boot.kernelParams` are load-bearing for low-power residency.
- Hibernate uses a btrfs swapfile at `/swap/swapfile` with `resume_offset=39068928`. If you resize/recreate the swapfile, recompute the offset. See `HIBERNATE-SETUP.md`.
- ithc loses state across hibernate — the `surface-touchscreen-resume` systemd service reloads it and restarts iptsd. Don't drop it.

## lan-mouse (KVM)

Runs as a per-user systemd service defined in `common/networking.nix`. Listens on TCP/UDP **4343** (4242 is taken by nebula). The `harry` installed config writes a `~/.config/lan-mouse/config.toml` via an activation script pointing at `trunkie.local`. See `lan-mouse-client.md` / `lan-mouse-server.md`.

## Conventions

- ISO builds use `gzip -Xcompression-level 1` for faster (larger) images during dev.
- `iso-packages.nix` is shared between installer and installed configs — packages added there land in both.
- Kernel rebuilds are cached; only config changes trigger them.
