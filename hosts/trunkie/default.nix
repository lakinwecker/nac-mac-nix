# Threadripper 1950X desktop — hostname "trunkie"
# 4-disk btrfs RAID1 (see hosts/trunkie/disko-config.nix):
#   root mirror  Force MP500 224G (onboard M.2) + Intel SSDSC2CW240A3 224G (SATA)
#   home mirror  ADATA SX8200 Pro 1.9T + 2TB NVMe, both on the DIMM.2 riser
{ pkgs, lib, ... }:
{
  hardware.amdgpu.initrd.enable = true;
  environment.systemPackages = with pkgs; [
    lm_sensors
    btrfs-progs  # btrfs device stats, scrub, etc.
    smartmontools  # disk health monitoring
  ];

  # ── btrfs health ─────────────────────────────────────────────────────
  # Weekly scrub to detect silent corruption / bit-rot on both arrays
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" "/home" ];
  };

  # ── SMART monitoring ─────────────────────────────────────────────────
  # Alert on disk pre-failure conditions
  services.smartd = {
    enable = true;
    autodetect = true;  # monitor all drives
  };

  # earlyoom (common) wants systembus-notify on; smartd's module defaults it
  # off. Keep it on — earlyoom's OOM dbus notifications are the reason.
  services.systembus-notify.enable = lib.mkForce true;
}
