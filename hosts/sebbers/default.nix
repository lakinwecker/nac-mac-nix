# AMD laptop — hostname "sebbers"
{ lib, pkgs, ... }:
{
  hardware.amdgpu.initrd.enable = true;

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
      RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_BAT = "on";
      PCIE_ASPM_ON_BAT = "powersupersave";
      NMI_WATCHDOG = 0;
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
    };
  };
  powerManagement.powertop.enable = true;
  environment.systemPackages = with pkgs; [ powertop lm_sensors ];
}
