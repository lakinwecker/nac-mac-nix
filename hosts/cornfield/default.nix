# Lenovo ThinkPad T460 (Skylake)
{ pkgs, ... }:
{
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "usb_storage" "sd_mod" "sdhci_pci"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
    };
  };
  services.thermald.enable = true;

  environment.systemPackages = with pkgs; [ powertop lm_sensors ];
}
