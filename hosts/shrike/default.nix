# Dell XPS 16 9650 (2026) — Intel Panther Lake (Core Ultra Series 3) — hostname "shrike"
# Top-spec config: Core Ultra X9 388H, Arc Xe3 iGPU (no discrete GPU this generation),
# 64GB LPDDR5x-9600, 4TB NVMe, 16" OLED 2880x1800 touch.
{ lib, pkgs, ... }:
{
  # ── Graphics (Intel Arc Xe3, integrated) ───────────────────────────
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # ── Boot / initrd ──────────────────────────────────────────────────
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    "nvme"
    "nvme_core"
    "xhci_pci"
    "thunderbolt"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "nvme" ];

  boot.kernelParams = [
    # Intel Panel Self-Refresh causes input stutter on idle screens —
    # same fix as roach. Revisit once Panther Lake i915/Xe driver matures.
    "i915.enable_psr=0"
  ];

  # ── Sensors (ambient light, accelerometer on touch chassis) ────────
  hardware.sensor.iio.enable = true;

  # ── IRQ balancing — keep CPU0 from getting saturated under input ───
  services.irqbalance.enable = true;

  # ── USB HID autosuspend ────────────────────────────────────────────
  # Same rationale as roach — autosuspend on input devices causes
  # 100-500ms wake-from-idle stutter for negligible power savings.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="e0", TEST=="power/control", ATTR{power/control}="on"
  '';

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
      USB_EXCLUDE_BTUSB = 1;
      WIFI_PWR_ON_BAT = "on";
      WIFI_PWR_ON_AC = "off";
      PCIE_ASPM_ON_BAT = "powersupersave";
      PCIE_ASPM_ON_AC = "default";
      NMI_WATCHDOG = 0;
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
    };
  };
  powerManagement.enable = true;

  environment.systemPackages = with pkgs; [ powertop lm_sensors ];
}
