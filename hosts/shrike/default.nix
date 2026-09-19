# Dell XPS 16 9650 — Intel Panther Lake (Core Ultra X9 388H, Arc Xe3 iGPU),
# 64GB LPDDR5x, 4TB NVMe, 16" OLED 2880x1800 touch.
{ lib, pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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
  boot.initrd.kernelModules = [
    "nvme"
    # Haptic touchpad — I2C HID on Panther Lake
    "i2c_hid_acpi"
    "i2c_designware_platform"
    "i2c_designware_core"
    "intel_lpss"
    "intel_lpss_pci"
    "hid_multitouch"
  ];

  boot.kernelParams = [
    "i915.enable_psr=0"   # PSR causes input stutter on idle screens
  ];

  hardware.sensor.iio.enable = true;
  services.irqbalance.enable = true;

  # USB HID autosuspend off: 100-500ms wake-from-idle stutter, negligible saving.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="e0", TEST=="power/control", ATTR{power/control}="on"
  '';

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
