# Surface Pro 9 (Intel) — hostname "harry"
{ lib, pkgs, ... }:
{
  hardware.microsoft-surface.kernelVersion = "stable";
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.kernelPatches = [{
    name = "disable-rust";
    patch = null;
    structuredExtraConfig = { RUST = lib.mkForce lib.kernel.no; };
  }];

  # Type Cover at LUKS prompt — modules matched from running system via lsmod/sysfs
  boot.initrd.kernelModules = [
    "pinctrl_tigerlake"
    "intel_lpss"
    "intel_lpss_pci"
    "8250_dw"
    "crc_itu_t"
    "surface_aggregator"
    "surface_aggregator_registry"
    "surface_aggregator_hub"
    "surface_hid_core"
    "surface_hid"
    "hid_surface"
    "hid_multitouch"
    "ithc"
  ];

  # surface_gpe causes wake failures when Type Cover is closed
  # during suspend — handle lid via logind instead
  boot.blacklistedKernelModules = [ "surface_gpe" ];

  services.iptsd.enable = true;
  hardware.sensor.iio.enable = true;

  # ── Power management (TLP) ─────────────────────────────────────────
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_AC = "performance";

      CPU_BOOST_ON_BAT = 0;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;
      RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_BAT = "on";
      PCIE_ASPM_ON_BAT = "powersupersave";
      NMI_WATCHDOG = 0;
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
    };
  };
  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  # ── Sleep / hibernate ──────────────────────────────────────────────
  # SP9 only supports s2idle (Modern Standby) — no S3/deep in firmware.
  # These params help s2idle actually reach S0ix low-power residency.
  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "i915.enable_psr=0"       # panel self-refresh can block wake
    "resume_offset=39068928"
  ];
  boot.resumeDevice = "/dev/mapper/cryptroot";

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "yes";
    AllowHibernation = "yes";
    AllowSuspendThenHibernate = "yes";
    SuspendState = "freeze";
    HibernateDelaySec = "30min";
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
  };

  # Reload ithc + iptsd after resume — touchpad loses state on hibernate.
  systemd.services.surface-touchscreen-resume = {
    description = "Reload ithc and restart iptsd after resume (Surface Pro 9)";
    wantedBy = [ "post-resume.target" ];
    after = [ "post-resume.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "surface-touchscreen-resume" ''
        ${pkgs.kmod}/bin/modprobe -r ithc 2>/dev/null || true
        ${pkgs.kmod}/bin/modprobe ithc 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl restart iptsd 2>/dev/null || true
      '';
    };
  };

  # Prevent XHCI (USB 3.0) from triggering instant wake
  powerManagement.powerDownCommands = ''
    for dev in XHCI XHC; do
      if grep -q "$dev.*enabled" /proc/acpi/wakeup; then
        echo "$dev" > /proc/acpi/wakeup
      fi
    done
  '';

  # ── Swap (hibernate) ───────────────────────────────────────────────
  # Btrfs swapfile — set NOCOW before creation
  system.activationScripts.swapNocow = {
    text = ''
      if [ -d /swap ]; then
        ${pkgs.e2fsprogs}/bin/chattr +C /swap 2>/dev/null || true
      fi
    '';
  };
  swapDevices = [{ device = "/swap/swapfile"; size = 32 * 1024; }];

  environment.systemPackages = with pkgs; [ powertop lm_sensors ];
}
