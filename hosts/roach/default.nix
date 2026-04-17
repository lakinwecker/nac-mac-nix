# Asus TUF Gaming F16 (FX608JM) — Intel Raptor Lake + NVIDIA RTX
# hostname "roach"
{ lib, pkgs, config, ... }:
{
  # ── ASUS services ──────────────────────────────────────────────────
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

  # supergfxd opens /etc/supergfxd.conf with O_RDWR | O_CREAT and
  # panics if it can't (with the misleading "The directory ... is
  # missing" message). NixOS's environment.etc would make it a
  # symlink to the read-only nix store, which fails the O_RDWR
  # open. Write it as a real mutable file via an activation
  # script instead. Format is JSON, schema confirmed against
  # supergfxctl 5.2.7's GfxConfig struct.
  system.activationScripts.supergfxdConfig = {
    deps = [ "etc" ];
    text = ''
      cat > /etc/supergfxd.conf <<'JSON'
      {
        "mode": "Integrated",
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

  # ── NVIDIA GPU ─────────────────────────────────────────────────────
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # Wayland / Hyprland on NVIDIA
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  # ── Boot / initrd ─────────────────────────────────────────────────
  # Systemd-based stage-1 gives an emergency shell on failure
  boot.initrd.systemd.enable = true;

  # Initrd needs NVMe drivers or the second drive's partlabel
  # symlinks race and never appear, hanging stage-1 on
  # "waiting for /dev/disk/by-partlabel/disk-home-luks".
  boot.initrd.availableKernelModules = [
    "nvme"
    "nvme_core"
    "vmd"        # Intel VMD — often enabled in BIOS on Raptor Lake laptops
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
  '';

  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
    # Disable Intel GPU Panel Self-Refresh. PSR entry during
    # static screen + PSR exit on input events causes 50-500ms
    # stutters that look like keyboard+mouse+compositor freezing
    # together. Single most common Intel-laptop input-stutter fix.
    "i915.enable_psr=0"
  ];

  # ── IRQ balancing ──────────────────────────────────────────────────
  # Distribute hardware IRQs across cores instead of piling on CPU0.
  # Prevents input stutter when CPU0 is momentarily saturated.
  services.irqbalance.enable = true;

  # ── USB HID autosuspend ────────────────────────────────────────────
  # Disable USB autosuspend for HID (input) devices. USB mice and
  # keyboards don't meaningfully save power from autosuspend, but
  # the first event after an idle window incurs a 100-500ms wake
  # penalty that shows up as "mouse froze for a moment."
  services.udev.extraRules = ''
    # USB HID (bInterfaceClass 03) — disable autosuspend
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
    # Also target the parent device for class-03 children
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="00", ATTR{product}=="*Mouse*", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="00", ATTR{product}=="*Keyboard*", TEST=="power/control", ATTR{power/control}="on"
  '';

  # ── Power management (TLP) ────────────────────────────────────────
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
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 40;
      RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 1;
      WIFI_PWR_ON_BAT = "off";
      WIFI_PWR_ON_AC = "off";
      PCIE_ASPM_ON_BAT = "default";
      NMI_WATCHDOG = 0;
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
    };
  };
  powerManagement.powertop.enable = false;
  environment.systemPackages = with pkgs; [ powertop lm_sensors ];
}
