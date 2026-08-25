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

  # No surface_gpe blacklist: it never binds here anyway. DMI sys_vendor is
  # " Microsoft Corporation" (leading space) and the driver uses DMI_EXACT_MATCH.

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

      CPU_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_AC = 1;
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

  # ── Sleep ──────────────────────────────────────────────────────────
  # SP9 only supports s2idle (Modern Standby) — no S3/deep in firmware.
  # Hibernate is deliberately not configured; see docs/suspend-harry.md.
  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "i915.enable_psr=0"       # panel self-refresh can block wake
    # Without this the Thunderbolt hotplug bridge (00:07.0) claims an I/O window
    # containing the ACPI PM1/GPE0 blocks; they read all-ones after s2idle and
    # the SCI storms. Check nesting in /proc/ioports before changing.
    "pci=hpiosize=0"
  ];

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "yes";
    SuspendState = "freeze";
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  # Default is HybridSleep, which needs a hibernate image we don't have.
  services.upower.criticalPowerAction = "PowerOff";

  # Reload ithc + iptsd after resume — touchscreen loses state across sleep.
  # Use resumeCommands, not a unit on post-resume.target: that target does not
  # exist in nixpkgs, so the old unit never ran on any boot.
  powerManagement.resumeCommands = ''
    ${pkgs.kmod}/bin/modprobe -r ithc 2>/dev/null || true
    ${pkgs.kmod}/bin/modprobe ithc 2>/dev/null || true
    for unit in $(${pkgs.systemd}/bin/systemctl list-units --plain --no-legend 'iptsd@*' | ${pkgs.gawk}/bin/awk '{print $1}'); do
      ${pkgs.systemd}/bin/systemctl restart "$unit" 2>/dev/null || true
    done
    # Restart iio-hyprland — auto-rotation stops working after suspend
    ${pkgs.procps}/bin/pkill iio-hyprland 2>/dev/null || true
    ${pkgs.coreutils}/bin/sleep 1
    ${pkgs.util-linux}/bin/runuser -u lakin -- ${pkgs.iio-hyprland}/bin/iio-hyprland eDP-1 &
  '';

  # Prevent XHCI (USB 3.0) from triggering instant wake
  powerManagement.powerDownCommands = ''
    for dev in XHCI XHC; do
      if grep -q "$dev.*enabled" /proc/acpi/wakeup; then
        echo "$dev" > /proc/acpi/wakeup
      fi
    done
  '';

  # ── Swap ───────────────────────────────────────────────────────────
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
