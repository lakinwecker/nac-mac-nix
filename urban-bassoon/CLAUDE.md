# NixOS Surface Pro 9 Installer ISO

Flake-based custom NixOS installer ISO with linux-surface kernel patches for Surface Pro 9 (Intel).

## Project Structure

- `flake.nix` - Main flake definition, imports nixos-hardware surface module
- `iso-packages.nix` - User packages to include in the live ISO

## Build

```bash
nix build .#nixosConfigurations.surface-iso.config.system.build.isoImage
```

Output: `./result/iso/nixos-*.iso`

## Write to USB

```bash
sudo dd if=./result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Boot on Surface Pro 9

- Boot menu: Hold Volume Down + Power
- UEFI settings: Hold Volume Up + Power
- May need to disable Secure Boot initially

## Key Dependencies

- `nixos-hardware.nixosModules.microsoft-surface-pro-intel` - Surface kernel + drivers
- `services.iptsd.enable` - Touchscreen/pen support
- ZFS disabled (`boot.supportedFilesystems.zfs = lib.mkForce false`) - incompatible with surface kernel

## Notes

- Kernel builds are cached; only config changes trigger rebuilds
- Using GNOME graphical installer base
- `gzip -Xcompression-level 1` for faster (but larger) ISO builds during dev
