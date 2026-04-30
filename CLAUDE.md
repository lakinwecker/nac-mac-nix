# CLAUDE.md

Flake-based NixOS configurations for personal machines, plus matching live installer ISOs.

## Machines

| Host | Hardware | Desktop | User |
|------|----------|---------|------|
| harry | Surface Pro 9 (Intel) | Hyprland | lakin |
| sebbers | AMD laptop | Hyprland | lakin |
| trunkie | Threadripper desktop | Hyprland | lakin |
| roach | Asus TUF F16 (Intel + NVIDIA) | Hyprland | lakin |
| shrike | Dell XPS 16 9650 (Intel Panther Lake) | Hyprland | lakin |
| souris | Dell XPS 13 9360 (Kaby Lake) | GNOME | souris |
| cornfield | ThinkPad T460 (Skylake) | XFCE | clown |

## Build & Install

See [docs/build.md](docs/build.md).

## Architecture

`machines.nix` is the **machine registry** — a single attrset keyed by hostname declaring each machine's desktop, hardware modules, username, and any overrides. `flake.nix` imports it and generates all `nixosConfigurations` (N hosts x {iso, installed}) via `mkIso`/`mkInstalled` helpers. To add a machine: add an entry to `machines.nix` + create `hosts/<name>/default.nix`.

### Machine registry fields (`machines.nix`)

- `desktop` — `"hyprland"` | `"xfce"` | `"gnome"` (required)
- `username` — defaults to `"lakin"`
- `hardware` — list of `nixos-hardware` module name strings, defaults to `[]`
- `hyprHostConfig` / `hyprWallpaper` / `hyprgrass` — Hyprland-specific overrides
- `xfceWallpaper` / `xfceAvatar` — XFCE-specific overrides
- `ollamaCuda` — enables CUDA ollama
- `diskoConfig` — path to custom disko layout, defaults to `./disko-config.nix`
- `dualDrive` — signals `install.sh` to require `--home-disk`
- `extraModules` — list of extra NixOS modules

### Directory layout

```
machines.nix         Machine registry (one entry per host)
common/              Shared config (networking, desktop, audio, packages, user)
hosts/<name>/        Hardware-specific config per machine
hypr/                Hyprland desktop module
xfce/                XFCE desktop module
gnome/               GNOME desktop module
ghostty/ nvim/ fish/ Program modules (imported by common/default.nix)
starship/ bin/ zellij/ ai/
```

### Module composition

- `commonModules = [ ./common ]` — imports themed sub-modules + program directories (not desktop environment).
- Desktop environment (`./hypr`, `./xfce`, or `./gnome`) is selected by the `desktop` field in `machines.nix`.
- Hardware modules are resolved from string names via `nixos-hardware.nixosModules.${name}`.
- `specialArgs` are computed per machine from the registry entry by `mkSpecialArgs`.
- Shared settings go in `common/*.nix`. Hardware-specific settings go in `hosts/<name>/default.nix`.

## harry (Surface Pro 9) specifics

- Type Cover at LUKS prompt needs `pinctrl_tigerlake`, `intel_lpss*`, `surface_aggregator*`, `surface_hid*`, `hid_multitouch`, `ithc` in `boot.initrd.kernelModules`. Don't remove without testing.
- `surface_gpe` is blacklisted (wake failures with Type Cover closed).
- Firmware only supports s2idle. `mem_sleep_default=s2idle` and `i915.enable_psr=0` are load-bearing.
- Hibernate: btrfs swapfile at `/swap/swapfile` with `resume_offset=39068928`. Recompute offset if swapfile changes.
- `surface-touchscreen-resume` service reloads ithc after hibernate. Don't drop it.

## Conventions

- ISO builds use `gzip -Xcompression-level 1` for faster (larger) images during dev.
- `iso-packages.nix` is shared between installer and installed configs.
- lan-mouse listens on TCP/UDP **4343** (4242 is taken by nebula).
