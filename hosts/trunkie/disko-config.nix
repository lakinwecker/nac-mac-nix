{ lib, ... }:
{
  # Trunkie — 4-disk RAID1 layout (Threadripper 1950X desktop, ROG Zenith Extreme)
  #
  # Physical slots (the board has 1 onboard M.2 + 2 on the DIMM.2 riser, and
  # all three are occupied — there is no free M.2 socket):
  #   root0  Force MP500 224G       onboard M.2 (under the PCH heatsink)
  #   root1  Intel SSDSC2CW240A3    SATA
  #   home0  ADATA SX8200 Pro 1.9T  DIMM.2 slot 1
  #   home1  2TB NVMe               DIMM.2 slot 2, replacing the WD SN550 931G
  #
  # Root mirror (btrfs RAID1):
  #   ESP lives on root0 only. Both members LUKS-encrypted; btrfs spans both.
  #   Subvolumes: /, /nix   (no swap — trunkie does not hibernate)
  #
  # Home mirror (btrfs RAID1):
  #   Both members LUKS-encrypted; btrfs spans both. Subvolume: /home
  #
  # ── Why the mkfs lives on the *second* member of each pair ──────────
  # disko has no dependency ordering for multi-device btrfs. Its btrfs type
  # leaves `_meta` as `_dev: {}`, so it contributes no deviceDependencies (only
  # bcachefs, lvm_pv, mdraid and zfs do). With nothing to sort by, devices are
  # created in `lib.attrNames` order — i.e. alphabetically:
  #
  #   home0 -> home1 -> root0 -> root1
  #
  # So whichever member runs `mkfs.btrfs` must sort AFTER the member it names
  # in extraArgs, or that /dev/mapper node does not exist yet and mkfs fails
  # partway through the install, with the disks already repartitioned.
  #
  # Hence: root0 and home0 are LUKS-only, and root1/home1 carry the btrfs
  # content and reference their partner. Do not move the btrfs block back onto
  # root0/home0, and do not rename these attributes such that the mkfs owner
  # sorts first.
  #
  # Install command (always pass by-id — NVMe enumeration order is not stable):
  #   ./install.sh trunkie --disk root0=/dev/disk/by-id/... \
  #                        --disk root1=/dev/disk/by-id/... \
  #                        --disk home0=/dev/disk/by-id/... \
  #                        --disk home1=/dev/disk/by-id/...

  disko.devices = {
    disk = {
      root0 = {
        # Primary root NVMe (224G) — carries the ESP, and the RAID1 partner
        # that root1's mkfs references. No filesystem of its own.
        device = lib.mkDefault "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              # 1G rather than the usual 512M: NixOS keeps a kernel+initrd per
              # generation, and this machine will accumulate them.
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot0";
                passwordFile = "/tmp/disk-password";
                settings.allowDiscards = true;
                # No filesystem — root1's mkfs adds this device to the array.
              };
            };
          };
        };
      };

      root1 = {
        # Secondary root SATA SSD (224G) — runs the mkfs for the root mirror.
        device = lib.mkDefault "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot1";
                passwordFile = "/tmp/disk-password";
                settings.allowDiscards = true;
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L" "root" "-d" "raid1" "-m" "raid1" "/dev/mapper/cryptroot0" ];
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                  };
                };
              };
            };
          };
        };
      };

      home0 = {
        # Primary home NVMe (ADATA 1.9T) — RAID1 partner that home1's mkfs
        # references. No filesystem of its own.
        device = lib.mkDefault "/dev/nvme1n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypthome0";
                passwordFile = "/tmp/disk-password";
                settings.allowDiscards = true;
              };
            };
          };
        };
      };

      home1 = {
        # Secondary home NVMe (2T) — runs the mkfs for the home mirror.
        device = lib.mkDefault "/dev/nvme2n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypthome1";
                passwordFile = "/tmp/disk-password";
                settings.allowDiscards = true;
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L" "home" "-d" "raid1" "-m" "raid1" "/dev/mapper/crypthome0" ];
                  subvolumes = {
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
