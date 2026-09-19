{ lib, ... }:
{
  # One btrfs filesystem per NVMe drive, not spanned: /home is capped at the
  # single ~930 GB disk, but one disk failing does not take out the other.
  disko.devices = {
    disk = {
      main = {
        # by-id: NVMe enumeration order could otherwise misroute the format.
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
