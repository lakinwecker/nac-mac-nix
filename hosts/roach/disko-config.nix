{ lib, ... }:
{
  # Two separate btrfs filesystems, one per NVMe drive.
  # - main (nvme0n1): ESP + LUKS cryptroot → btrfs with /, /nix
  # - home (nvme1n1):        LUKS crypthome → btrfs with /home
  #
  # No multi-device spanning — simpler, survives one-disk failure
  # (the surviving disk still boots or still has /home data).
  # Tradeoff: /home is capped at ~930 GB; can't grow past that
  # without adding capacity.
  disko.devices = {
    disk = {
      main = {
        # WD SN5000S 1TB — hard-coded by-id so NVMe enumeration
        # order (nvme0n1 vs nvme1n1) cannot misroute the format.
        device = "/dev/disk/by-id/nvme-WD_PC_SN5000S_SDEQNSJ-1T00-1002_25184R800947";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
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
      home = {
        # Kingston SNV3S 1TB — hard-coded by-id for the same reason.
        device = "/dev/disk/by-id/nvme-KINGSTON_SNV3S1000G_50026B76873F13D6";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypthome";
                passwordFile = "/tmp/disk-password";
                settings.allowDiscards = true;
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L" "home" ];
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
