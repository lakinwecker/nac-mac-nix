# Threadripper 1950X desktop — 3-disk layout, see ./disko-config.nix
{ pkgs, lib, ... }:
{
  hardware.amdgpu.initrd.enable = true;

  # Also gives one passphrase prompt for all three LUKS containers, not three.
  boot.initrd.systemd.enable = true;
  environment.systemPackages = with pkgs; [
    lm_sensors
    btrfs-progs
    smartmontools
    lutris
  ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" "/home" ];
  };

  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # smartd's module defaults this off; earlyoom (common) needs it on for its
  # OOM dbus notifications.
  services.systembus-notify.enable = lib.mkForce true;

  # Always-on box: power state is manual. Pairs with hyprIdleTimeouts.suspend = 0
  # in machines.nix.
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

  # ZSA Moonlander (Oryx web flashing). The packaged rules TAG+="uaccess", so
  # ignore the plugdev group in ZSA's instructions — nothing to create.
  hardware.keyboard.zsa.enable = true;

  # The dock/KVM's USB NIC takes a second lease on the onboard NIC's subnet:
  # two default routes and intermittent connectivity. Matched by MAC because
  # enp8s0u1u4u4u3 changes if the dock moves ports.
  networking.networkmanager.unmanaged = [ "mac:8c:3b:4a:28:fd:9a" ];

  # Deauthorize the ASUS onboard bluetooth radio (bad with headsets) so bluez
  # picks the TP-Link dongle; onboard otherwise enumerates first and wins.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1868", ATTR{authorized}="0"
  '';
}
