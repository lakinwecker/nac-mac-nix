{ lib, ... }:
{
  # Single btrfs pool spanning both NVMe drives via two LUKS containers.
  # Data/metadata profile: single (~1.85 TB usable, any disk failure = total loss).
  # Backups are the safety net, not redundancy.
  #
  # Note: btrfs swapfiles are unsupported on multi-device filesystems,
  # so there is no /swap subvolume here. Add a dedicated swap partition
  # if hibernate is ever needed.
  disko.devices = {
    disk = {
      main = {
        device = lib.mkDefault "/dev/nvme0n1";
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
                  extraArgs = [ "-f" "-L" "pool" "-d" "single" "-m" "single" ];
                  # After mkfs on the first device, add the second LUKS device
                  # to the same btrfs pool, then rebalance so existing metadata
                  # is spread across both devices.
                  postCreateHook = ''
                    btrfs device add -f /dev/mapper/crypthome /mnt
                    btrfs balance start --full-balance /mnt
                  '';
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
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
      home = {
        device = lib.mkDefault "/dev/nvme1n1";
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
                # Placeholder btrfs — disko's luks type requires a content
                # node. It's immediately wiped and absorbed into the main
                # pool by the postCreateHook above (btrfs device add -f).
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
