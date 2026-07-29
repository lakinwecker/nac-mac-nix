# Port HyprPanel → Wayle (all Hyprland hosts)

**Date:** 2026-07-27
**Status:** Design — awaiting review

## Context & motivation

`hyprpanel` (`jas-singhfsu/HyprPanel`, AGS/TypeScript) was **archived upstream** and
subsequently **removed from nixpkgs**. After bumping the flake's `nixpkgs` input
(needed so the `next` Hyprland channel — 0.56.0 on gratch — gets
`wayland-protocols >= 1.49`), every Hyprland host now fails to evaluate because
`pkgs.hyprpanel` is a hard `throw`.

We are replacing the bar with **Wayle** (`wayle-rs/wayle`, Rust/GTK4, `wayle` in
nixpkgs, v0.6.0), a compositor-agnostic Wayland shell that provides the bar,
notification center, OSD, and wallpaper engine.

## Scope

- **Big-bang across all 5 Hyprland hosts** (harry, gratch, trunkie, roach, shrike).
  The bar lives in the shared `hypr/` module, so this is not host-local. All five
  are currently unbuildable until `hyprpanel` is removed.
- XFCE (cornfield) and GNOME (souris) hosts are unaffected.

## Guiding principle

**Mirror the existing HyprPanel integration pattern exactly**, swapping only the
tool. That pattern (in `hypr/default.nix`) is: package in `systemPackages` →
config file(s) in `/etc` → activation script copies the mode-matching variant to
`~/.config` → `exec-once` in `hyprland.conf` → `theme-toggle` swaps variant +
restarts on dark/light switch. No home-manager (this repo doesn't use it).

## Wayle facts (verified against the v0.6.0 binary)

- **Launch:** `wayle shell` — runs the full desktop shell (bar + notifications +
  OSD + wallpaper) in the foreground. (`wayle panel start/stop/restart` manage a
  daemon variant.)
- **Reload:** `wayle panel restart`.
- **Config:** `~/.config/wayle/config.toml` (TOML). Modules are configured once
  under `[modules.<name>]` and *referenced by string* in `[[bar.layout]]`
  `left`/`center`/`right` arrays.
- **Palette:** inline `[styling.palette]` with tokens
  `bg, surface, elevated, fg, fg-muted, primary, red, yellow, green, blue`.
  Modules reference derived tokens (`accent`, `bg-surface-elevated`,
  `border-accent`, `fg-subtle`, …) auto-derived from the palette.
- **No runtime theme-switch CLI and no `theme =` key.** Runtime switching is only
  via the `wayle panel settings` GUI. → dark/light is done by **swapping the
  whole config file + `wayle panel restart`**, exactly as HyprPanel did with its
  two JSONs.
- **Built-in notification daemon** (the `notifications` module). We must ensure no
  second notification daemon runs.
- Ground-truth schema captured from `wayle config default`
  (732-line reference; all module keys/defaults known).

## Layout mapping (HyprPanel → Wayle `[[bar.layout]]`)

Single layout, `monitor = "*"` (matches HyprPanel's `"*"` layout):

| Section | Modules (in order) |
|---------|--------------------|
| left    | `dashboard`, `hyprland-workspaces`, `window-title` |
| center  | `media` |
| right   | `volume`, `network`, `bluetooth`, `battery`, `notifications`, `systray`, `clock`, `world-clock` |

## Module config mapping

| Module | Key settings (Wayle) | Source (HyprPanel) |
|--------|----------------------|--------------------|
| `hyprland-workspaces` | `min-workspace-count = 10`, `display-mode = "label"`, `monitor-specific = false` | `bar.workspaces.workspaces = 10`, `showAllActive`, `monitorSpecific = false` |
| `clock` | `format = "%H:%M:%S"`, `dropdown-show-seconds = true` | `bar.clock.format = "%H:%M:%S"` |
| `world-clock` | `format = "{{ tz('America/New_York','%H:%M') }} \| {{ tz('UTC','%H:%M') }} \| {{ tz('Europe/Paris','%H:%M') }}"` | `worldclock.tz = [NY, UTC, Paris]`, divider `" \| "` |
| `notifications` | `popup-position = "bottom-right"`, `blocklist = ["discord","slack"]` | `notifications.position`, `notifications.ignore` |
| `media` | `label-max-length = 35` (default) | HyprPanel media module |
| `battery`/`network`/`bluetooth`/`volume`/`systray`/`window-title` | Wayle defaults, palette-driven colors | equivalent HyprPanel modules |

Modules present in HyprPanel with no meaningful config beyond placement keep
Wayle's defaults. HyprPanel extras without a Wayle equivalent (e.g. the granular
per-menu weather panel) are dropped or left at defaults — see caveats.

## Theming: two-variant dark/light

- Author **one shared base** (`config.toml` body: `general`, `bar`, `[[bar.layout]]`,
  all `[modules.*]`, `osd`, `wallpaper`) plus **two `[styling.palette]` blocks**:
  **Tokyo Night Storm** (dark) and **Tokyo Night Day** (light). Exact hexes are
  lifted from the existing `hypr/hyprpanel-config.json` /
  `hypr/hyprpanel-config-light.json` during implementation and reduced to Wayle's
  10 palette tokens.
- A Nix helper (analogous to the current `mkHyprpanelConfig`) concatenates
  base + palette to produce `config-dark.toml` and `config-light.toml`.
- Deploy to `/etc/wayle/config-{dark,light}.toml`.
- `system.activationScripts` copies the mode-matching variant (from
  `~/.local/state/theme-mode`, default dark) to `~/.config/wayle/config.toml`.

## `theme-toggle` change (`bin/scripts/theme-toggle`)

Replace the HyprPanel block (copy variant + `pkill hyprpanel-wrapped` + restart)
with:

```sh
wayle_src="/etc/wayle/config-$mode.toml"
wayle_dst="$HOME/.config/wayle/config.toml"
if [ -f "$wayle_src" ] && command -v wayle >/dev/null 2>&1; then
  install -m 0644 "$wayle_src" "$wayle_dst"
  wayle panel restart >/dev/null 2>&1 || true
fi
```

All other `theme-toggle` targets (dconf, hyprland borders, nvim, ghostty, claude,
signal) are unchanged.

## `hyprland.conf` change

`exec-once=hyprpanel` → `exec-once=wayle shell`.

## Package changes (`hypr/default.nix`)

- **Remove:** `hyprpanel`, and HyprPanel-only deps `libgtop`, `dart-sass`,
  `gtksourceview3`, `libsoup_3` (verify none is referenced elsewhere before
  removing).
- **Add:** `wayle`.
- **Keep:** general utilities that other components use (`matugen`, `pywal`,
  `bluez`, `pavucontrol`, `playerctl`, `brightnessctl`, `hyprsunset`, …).
- Wayle's runtime services (NetworkManager, BlueZ, PipeWire, UPower) are already
  enabled via the networking/audio modules.

## Open item: wallpaper

HyprPanel managed the wallpaper (`wallpaper.image = /etc/wallpaper.jpg`). Wayle's
wallpaper engine is configured per-monitor via `[[wallpaper.monitors]]`
(connector + path), and connectors differ per host (eDP-1 on laptops, DP-/HDMI-
on trunkie). **Recommended default:** enable Wayle's engine and set a single
`[[wallpaper.monitors]]` with the common laptop connector `eDP-1`, plus per-host
additions via the existing `hyprHostConfig`-style override where needed. If
per-monitor config proves fiddly, fall back to a dedicated `hyprpaper` unit.
This is the one detail to finalize during implementation.

## Fidelity caveats (accepted)

- HyprPanel's 400+ granular per-widget colors collapse into Wayle's ~10 palette
  tokens + per-module color overrides — same Tokyo Night *feel*, not
  pixel-identical menus.
- HyprPanel niceties without a 1:1 Wayle equivalent (specific menu internals,
  in-clock weather panel) are dropped or left at Wayle defaults.
- **Maturity risk:** Wayle is v0.6.0 (~92 open issues). Issue **#327** —
  "can't parse Hyprland *git* output on fullscreen" — may glitch workspaces/title
  in fullscreen on gratch (Hyprland 0.56.0). Acceptable for now; watch upstream.

## Out of scope

- Wallpaper cycling, `matugen`/`pywal`/`wallust` dynamic theming (keep static
  Tokyo Night; `theme-provider = "wayle"`).
- The `wayle panel settings` GUI workflow.
- Any change to XFCE/GNOME hosts.

## Verification

Per CLAUDE.md, **no full system builds**. Verify with:

- `nix-instantiate --parse` on edited `.nix` files.
- `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
  for each Hyprland host (harry, gratch, trunkie, roach, shrike) — confirms the
  module tree + Wayle config generation evaluate with no `hyprpanel` throw.
- TOML validity of generated `config-{dark,light}.toml` (e.g. `wayle` can parse
  it, or a `taplo`/`python -c tomllib` check).
- Real switch/visual validation is the user's, on a machine.

## Cleanup

Remove the stray `~/.config/wayle/config.toml.example` written by
`wayle config default` during research (not part of the repo).
