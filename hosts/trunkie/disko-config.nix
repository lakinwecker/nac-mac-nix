{ lib, ... }:
{
  # Trunkie — 3-disk layout (Threadripper 1950X desktop, ROG Zenith Extreme)
  #
  #   root   WD SN550 931G          onboard M.2; ESP + single-device btrfs
  #   home0  ADATA SX8200 Pro 1.9T  DIMM.2 slot 1
  #   home1  WD Black SN770 1.8T    DIMM.2 slot 2
  #
  # Root is not mirrored: it is reproducible from this flake, so a root disk
  # failure costs a reinstall, not data. Only /home gets RAID1.
  #
  # The home mkfs lives on home1, not home0, and this matters: disko has no
  # dependency ordering for multi-device btrfs (its btrfs type leaves _meta as
  # an empty _dev, contributing no deviceDependencies), so devices are created
  # in lib.attrNames order — home0, home1, root. Whichever member runs
  # mkfs.btrfs must sort AFTER the member it names in extraArgs, or that
  # /dev/mapper node does not exist yet and mkfs fails mid-install with the
  # disks already repartitioned. Do not move the btrfs block onto home0.
  #
  # Install (always by-id — NVMe enumeration order is not stable):
  #   ./install.sh trunkie --disk root=/dev/disk/by-id/... \
  #                        --disk home0=/dev/disk/by-id/... \
  #                        --disk home1=/dev/disk/by-id/...

  disko.devices = {
    disk = {
      root = {
        device = lib.mkDefault "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              # 1G rather than 512M: NixOS keeps a kernel+initrd per generation.
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
                name = "cryptroot";
                passwordFile = "/tmp/disk-password";
                settings.allowDiscards = true;
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L" "root" ];
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
        # RAID1 partner that home1's mkfs references. No filesystem of its own.
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
        # Runs the mkfs for the home mirror.
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
