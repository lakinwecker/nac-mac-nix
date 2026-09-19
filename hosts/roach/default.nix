# Asus TUF Gaming F16 (FX608JM) — Intel Raptor Lake + NVIDIA RTX
{ lib, pkgs, config, username, ... }:
{
  nix.settings.trusted-users = [ "root" username ];

  services.asusd.enable = true;
  services.supergfxd.enable = true;

  systemd.services.asus-leds = {
    description = "Set ASUS TUF keyboard RGB";
    after = [ "asusd.service" ];
    requires = [ "asusd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "asus-leds-init" ''
        ${pkgs.asusctl}/bin/asusctl aura effect static -c 7aa2f7
        ${pkgs.asusctl}/bin/asusctl leds set low
        ${pkgs.asusctl}/bin/asusctl aura power-tuf --awake true --keyboard --boot false --sleep false
      '';
    };
  };

  # supergfxd opens /etc/supergfxd.conf O_RDWR and panics on a read-only nix
  # store symlink, so environment.etc can't be used — write a real file.
  system.activationScripts.supergfxdConfig = {
    deps = [ "etc" ];
    text = ''
      cat > /etc/supergfxd.conf <<'JSON'
      {
        "mode": "Hybrid",
        "vfio_enable": false,
        "vfio_save": false,
        "always_reboot": false,
        "no_logind": false,
        "logout_timeout_s": 180,
        "hotplug_type": "None"
      }
      JSON
      chmod 0644 /etc/supergfxd.conf
    '';
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # AQ_DRM_DEVICES must be colon-free (aquamarine splits on ':'), hence the
  # /dev/dri/igpu symlink in services.udev.extraRules below. Render on the
  # iGPU: setting GBM_BACKEND/__GLX_VENDOR_LIBRARY_NAME to nvidia pins the
  # dGPU in D0.
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    AQ_DRM_DEVICES = "/dev/dri/igpu";
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  boot.initrd.systemd.enable = true;

  # Without nvme here the second drive's partlabel symlinks race and stage-1
  # hangs on "waiting for /dev/disk/by-partlabel/disk-home-luks".
  boot.initrd.availableKernelModules = [
    "nvme"
    "nvme_core"
    "vmd"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "nvme" "vmd" ];

  boot.extraModprobeConfig = ''
    options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y
    options rtw89_core disable_ps_mode=y
    options btusb enable_autosuspend=n
  '';

  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
    "i915.enable_psr=0"   # PSR entry/exit causes 50-500ms input stutter
  ];

  services.irqbalance.enable = true;

  # USB HID autosuspend off: 100-500ms wake-from-idle stutter, negligible saving.
  services.udev.extraRules = ''
    # iGPU card-node alias — see AQ_DRM_DEVICES above
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="0000:00:02.0", SYMLINK+="dri/igpu"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="e0", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="00", ATTR{product}=="*Mouse*", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="00", ATTR{product}=="*Keyboard*", TEST=="power/control", ATTR{power/control}="on"
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
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 40;
      # Without this TLP never writes max_perf_pct on AC, so the 40% BAT cap
      # survives plugging in and the CPU stays clamped until reboot.
      CPU_MAX_PERF_ON_AC = 100;
      RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 1;
      WIFI_PWR_ON_BAT = "off";
      WIFI_PWR_ON_AC = "off";
      PCIE_ASPM_ON_BAT = "default";
      NMI_WATCHDOG = 0;
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
    };
  };
  powerManagement.powertop.enable = false;

  # Pairs with hyprSuspendOnAc = false (machines.nix); lid still suspends on battery.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  # Must match eDP-1's scale in machines.nix (and xwayland.force_zero_scaling there).
  programs.steam.package = pkgs.steam.override {
    extraEnv = {
      STEAM_FORCE_DESKTOPUI_SCALING = "1.25";
    };
  };

  environment.systemPackages = with pkgs; [ powertop lm_sensors iw ];
}
