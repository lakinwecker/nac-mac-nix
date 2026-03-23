# NixOS Surface Pro 9 Installation

## 1. Find your disk

```bash
lsblk
ls -la /dev/disk/by-id/
```

## 2. Set your LUKS password

```bash
echo "your-password" > /tmp/disk-password
```

## 3. Install

```bash
sudo disko-install --flake /iso/flake#surface --disk main /dev/nvme0n1
```

Or with the full disk ID (recommended):

```bash
sudo disko-install --flake /iso/flake#surface --disk main /dev/disk/by-id/nvme-SAMSUNG_MZVL2512...
```

## 4. Reboot

```bash
reboot
```

You'll be prompted for your LUKS password at boot.

## 5. After first boot

Login as `lakin` with password `changeme`, then:

```bash
passwd
```

## Partition Layout

- `/boot` - 512M EFI partition (vfat)
- LUKS encrypted btrfs with subvolumes:
  - `/` - root
  - `/home` - home
  - `/nix` - nix store
