{ lib, ... }:
{
  # root 931G unmirrored (reproducible from this flake); /home is btrfs RAID1
  # across home0 + home1.
  #
  # The home mkfs must stay on home1: disko creates devices in attrName order
  # (home0, home1, root) with no dependency ordering for multi-device btrfs, so
  # the member running mkfs must sort AFTER the member it names in extraArgs.
  # Moving the btrfs block onto home0 fails mid-install, disks already wiped.
  #
  # Install by-id — NVMe enumeration order is not stable:
  #   ./install.sh trunkie --disk root=... --disk home0=... --disk home1=...

  disko.devices = {
    disk = {
      root = {
        device = lib.mkDefault "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              # 1G, not 512M: NixOS keeps a kernel+initrd per generation.
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
        # RAID1 partner referenced by home1's mkfs. No filesystem of its own.
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
        # Runs the mkfs for the home mirror — see the note at the top.
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
