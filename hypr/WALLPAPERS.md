# Wallpaper sources

Per-host wallpapers live next to `default.nix` and are selected via the
`hyprWallpaper` specialArg passed from each `nixosConfiguration` in
`flake.nix`. Hosts without an override use `wallpaper.jpg`.

| File | Host(s) | Resolution | Source |
|---|---|---|---|
| `wallpaper.jpg` | surface, laptop, desktop (default) | — | original repo asset |
| `wallpaper-roach.jpg` | roach (asus-tuf) | 2560×1600 | The Witcher 3: Wild Hunt — Geralt of Rivia. Downloaded from https://r4.wallpaperflare.com/wallpaper/617/283/733/the-witcher-3-wild-hunt-video-games-the-witcher-geralt-of-rivia-wallpaper-a816dcda2f8ca7499e8069f27299cbe0.jpg |

## Adding a new one

1. Drop the image at `hypr/wallpaper-<name>.jpg`.
2. Add a row to the table above with the source URL.
3. In `flake.nix`, set `hyprWallpaper = ./hypr/wallpaper-<name>.jpg;` in
   the target host's `specialArgs` (both the host and its `-iso` variant).
