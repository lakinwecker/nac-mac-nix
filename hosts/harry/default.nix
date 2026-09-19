# Surface Pro 9 (Intel)
{ lib, pkgs, ... }:
{
  hardware.microsoft-surface.kernelVersion = "stable";
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.kernelPatches = [{
    name = "disable-rust";
    patch = null;
    structuredExtraConfig = { RUST = lib.mkForce lib.kernel.no; };
  }];

  # Load-bearing: the Type Cover is dead at the LUKS prompt without these.
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

  # No surface_gpe blacklist: DMI sys_vendor has a leading space and the driver
  # uses DMI_EXACT_MATCH, so it never binds here anyway.

  services.iptsd.enable = true;
  hardware.sensor.iio.enable = true;

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

  # All three are load-bearing for suspend — see docs/suspend-harry.md.
  # Firmware has no S3; PSR blocks wake; without hpiosize=0 the Thunderbolt
  # bridge overlaps the ACPI PM1/GPE0 blocks and the SCI storms after s2idle.
  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "i915.enable_psr=0"
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

  # Default HybridSleep needs a hibernate image we don't have.
  services.upower.criticalPowerAction = "PowerOff";

  # Touchscreen loses state across sleep. Must be resumeCommands, not a unit on
  # post-resume.target — that target does not exist in nixpkgs and never runs.
  powerManagement.resumeCommands = ''
    ${pkgs.kmod}/bin/modprobe -r ithc 2>/dev/null || true
    ${pkgs.kmod}/bin/modprobe ithc 2>/dev/null || true
    for unit in $(${pkgs.systemd}/bin/systemctl list-units --plain --no-legend 'iptsd@*' | ${pkgs.gawk}/bin/awk '{print $1}'); do
      ${pkgs.systemd}/bin/systemctl restart "$unit" 2>/dev/null || true
    done
    # auto-rotation stops working after suspend
    ${pkgs.procps}/bin/pkill iio-hyprland 2>/dev/null || true
    ${pkgs.coreutils}/bin/sleep 1
    ${pkgs.util-linux}/bin/runuser -u lakin -- ${pkgs.iio-hyprland}/bin/iio-hyprland eDP-1 &
  '';

  # XHCI otherwise triggers instant wake.
  powerManagement.powerDownCommands = ''
    for dev in XHCI XHC; do
      if grep -q "$dev.*enabled" /proc/acpi/wakeup; then
        echo "$dev" > /proc/acpi/wakeup
      fi
    done
  '';

  # btrfs swapfile needs NOCOW before creation.
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
