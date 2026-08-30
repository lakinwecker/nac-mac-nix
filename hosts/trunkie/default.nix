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

  # ── No suspend / hibernate ───────────────────────────────────────────
  # Always-on remote dev box; power state is manual only. hypridle's suspend
  # listener is dropped by hyprIdleTimeouts.suspend = 0 in machines.nix.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  services.logind.settings.Login = {
    HandleSuspendKey = "ignore";
    HandleSuspendKeyLongPress = "ignore";
    HandleHibernateKey = "ignore";
    HandleHibernateKeyLongPress = "ignore";
  };

  # ── ZSA Moonlander ───────────────────────────────────────────────────
  # Installs zsa-udev-rules, replacing the 50-zsa.rules file Oryx asks you to
  # write by hand, so web flashing and live training can reach the keyboard's
  # hidraw node without root.
  #
  # Ignore the plugdev group in ZSA's instructions: the packaged rules use
  #   SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3297", TAG+="uaccess"
  # so logind hands the active session an ACL on the device. That is per-login
  # rather than a static group, so there is nothing to create and nobody to add.
  hardware.keyboard.zsa.enable = true;

  # ── Network: onboard NIC only ────────────────────────────────────────
  # The dock/KVM's USB NIC (r8152) takes a second DHCP lease on the same
  # 192.168.50.0/24 as the onboard igb, so the host ends up with two addresses
  # and two default routes on one subnet — ARP flux and connectivity that drops
  # intermittently. Unmanaged leaves the link up but unconfigured; the dock's
  # video path through the KVM is unaffected.
  # Matched by MAC, not name: enp8s0u1u4u4u3 is derived from the USB topology
  # and silently changes if the dock moves to a different port or hub.
  networking.networkmanager.unmanaged = [ "mac:8c:3b:4a:28:fd:9a" ];

  # ── Bluetooth: onboard radio off, USB dongle only ────────────────────
  # 0b05:1868 is the ASUS onboard radio (bad with headsets); 2357:0604 is the
  # TP-Link 5.3 dongle we keep. Onboard enumerates first, so bluez picks it as
  # default unless it never binds at all. Both its interfaces are class e0,
  # so deauthorizing the whole device loses nothing else.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1868", ATTR{authorized}="0"
  '';
}
