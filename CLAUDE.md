# CLAUDE.md

Flake-based NixOS configurations for personal machines, plus matching live installer ISOs.

## Machines

| Host | Hardware | Desktop | User |
|------|----------|---------|------|
| harry | Surface Pro 9 (Intel) | Hyprland | lakin |
| gratch | AMD laptop | Hyprland | lakin |
| trunkie | Threadripper desktop | Hyprland | lakin |
| roach | Asus TUF F16 (Intel + NVIDIA) | Hyprland | lakin |
| shrike | Dell XPS 16 9650 (Intel Panther Lake) | Hyprland | lakin |
| souris | Dell XPS 13 9370 (Kaby Lake R) | GNOME | anita |
| cornfield | ThinkPad T460 (Skylake) | XFCE | clown |

## Build & Install

See [docs/build.md](docs/build.md).

## Backup

`backup.sh` builds and drives trunkie's backup pool (2x4TB btrfs RAID1 over
LUKS) and wraps the restic repo that mirrors it to OVH object storage. See
[docs/backup.md](docs/backup.md).

## trunkie migration

trunkie is being rebuilt from Arch to NixOS. Disk layout, pre-install steps,
and what is backed up where: [docs/trunkie-plan.md](docs/trunkie-plan.md).

## Binary cache

Planned, not built. attic on trunkie, storage on a 500GB subvolume of the SATA
backup pool, served over nebula to the other hosts. Decision, trade-offs and
open questions: [docs/binary-cache.md](docs/binary-cache.md).

## Architecture

`machines.nix` is the **machine registry** — a single attrset keyed by hostname declaring each machine's desktop, hardware modules, username, and any overrides. `flake.nix` imports it and generates all `nixosConfigurations` (N hosts x {iso, installed}) via `mkIso`/`mkInstalled` helpers. To add a machine: add an entry to `machines.nix` + create `hosts/<name>/default.nix`.

### Machine registry fields (`machines.nix`)

- `desktop` — `"hyprland"` | `"xfce"` | `"gnome"` (required)
- `username` — defaults to `"lakin"`
- `hardware` — list of `nixos-hardware` module name strings, defaults to `[]`
- `hyprHostConfig` / `hyprWallpaper` / `hyprgrass` / `hyprIdleTimeouts` / `hyprSuspendOnAc` / `hyprDynamicCursorsMode` — Hyprland-specific overrides
- `hyprlandChannel` — `"stable"` (default, v0.55.4, has hyprexpo + hyprgrass) | `"next"` (v0.56.0 + portal v1.4.0 for lan-mouse's libei input capture; has hyprexpo, but `hyprgrass = true` throws) | `"latest"` (v0.56.2 + portal v1.4.1; **no hyprexpo** — the fork's newest tag is v0.56.1+3, so nothing is published for v0.56.2 — and `hyprgrass = true` throws). Moves Hyprland, portal, and plugin pins in lockstep.
- `ghosttyOpacity` — ghostty `background-opacity`, 0.0–1.0, default `0.85`. Rendered with `builtins.toJSON`; `toString` would emit `0.950000`.
- `xfceWallpaper` / `xfceAvatar` — XFCE-specific overrides
- `ollamaCuda` — enables CUDA ollama
- `devTools` — heavier dev modules (nvim, zellij, ollama, latex), defaults to `true`
- `diskoConfig` — path to custom disko layout, defaults to `./disko-config.nix`
- `extraModules` — list of extra NixOS modules

### Directory layout

```
machines.nix         Machine registry (one entry per host)
common/              Shared config (networking, desktop, audio, bluetooth, packages, user)
hosts/<name>/        Hardware-specific config per machine
hypr/                Hyprland desktop module
xfce/                XFCE desktop module
gnome/               GNOME desktop module
ghostty/ nvim/ git/  Program modules (imported by common/default.nix)
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

## Hyprland Lua config

`hypr/hyprland.lua` — hyprlang was deprecated in 0.55 and is dropped in 0.57,
so the compositor config is Lua. `hyprlock.conf` and `hypridle.conf` still take
hyprlang and are unaffected. Per-host `hyprHostConfig` strings in `machines.nix`
and `hypr/hyprgrass.lua` are Lua too, since they are concatenated onto the same
file. https://hypr.land/news/26_lua/

Reference material is local, not on the wiki (which renders via JS and loses the
code blocks): the Hyprland package ships `share/hypr/hyprland.lua` (a worked
example) and `share/hypr/stubs/hl.meta.lua` (the whole `hl` API). Dispatcher
argument shapes live in the source at
`src/config/lua/bindings/LuaBindingsDispatchers.cpp`.

Verify any change with `Hyprland --verify-config -c <file>` before switching —
it catches bad keys, dispatcher shapes and Lua syntax without touching the
running session. Two caveats: it does not dlopen plugins, so `unknown config key
'plugin.*'` notices are first-pass artifacts rather than errors; and for the
same reason a plugin's own Lua namespace (`hl.plugin.hyprgrass`) is nil on that
first pass, so guard uses of it with `if hg then ... end`.

Gotchas found during the migration:
- `movetoworkspacesilent` is `hl.dsp.window.move({ workspace = N, follow = false })`.
- `hl.gesture`'s `action` takes a string, a table of start/update/finish
  callbacks, or a plain Lua function — a bare dispatcher errors, so wrap it.
- Plugin option keys are **renamed** for Lua: `luaConfigValueName` rewrites `:`
  to `.` and `-` to `_`, so `plugin:dynamic-cursors:shake:threshold` is
  `plugin.dynamic_cursors.shake.threshold`. `hyprctl getoption` still reports
  the legacy colon/hyphen name, which makes this easy to get backwards — check
  it live with `hyprctl eval` plus `getoption` rather than assuming.
- Plugins load *after* the first config pass, so their keys are unknown then;
  `handlePluginLoads()` calls `reload()` and the values apply on the second
  pass. That means `--verify-config` cannot validate plugin keys at all — a
  wrong one is silently ignored at runtime, leaving plugin defaults in place.

## Conventions

- ISO builds use `gzip -Xcompression-level 1` for faster (larger) images during dev.
- `iso-packages.nix` is shared between installer and installed configs.
- lan-mouse listens on TCP/UDP **4343** (4242 is taken by nebula).

## Verifying changes — do NOT run full builds

Do not run `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` or `nixos-rebuild build` to verify edits. These pull in kernels, hyprland, mesa, etc. and can pin all CPUs for tens of minutes when the cache misses. The user runs the real rebuild themselves.

For syntax/eval checks, use one of:
- `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` — evaluates the module tree without building anything.
- `nix flake check --no-build` — evaluates all outputs.
- `nix-instantiate --parse <file.nix>` — pure parse check for a single file.

If a real build is genuinely required, ask first.
