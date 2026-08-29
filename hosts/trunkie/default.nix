# Threadripper 1950X desktop — hostname "trunkie"
# 3-disk layout (see hosts/trunkie/disko-config.nix):
#   root         WD SN550 931G (onboard M.2), unmirrored
#   home mirror  ADATA SX8200 Pro 1.9T + WD Black SN770 1.8T, on the DIMM.2 riser
{ pkgs, lib, ... }:
{
  hardware.amdgpu.initrd.enable = true;

  # Emergency shell instead of a hang when stage-1 cannot find a device, and
  # one passphrase prompt for all three LUKS containers instead of three.
  boot.initrd.systemd.enable = true;
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
