# Threadripper 1950X desktop — hostname "trunkie"
# 4-disk btrfs RAID1: root mirror (2x224G NVMe+SATA) + home mirror (2x ~2T NVMe)
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
