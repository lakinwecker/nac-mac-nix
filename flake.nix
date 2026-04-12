{
  description = "NixOS Surface Pro 9 installer ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      # Tagged release — cacheable. Bump in lockstep with hyprgrass when needed.
      url = "github:hyprwm/Hyprland/v0.54.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # hyprgrass is Surface-only (touchscreen gestures). Tracks main; the
    # surface configs are the only ones that pass it through to hypr/default.nix.
    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, disko, hyprland, hyprgrass, ... }:
  let
    commonModules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ./hypr
      ./ghostty
      ./nvim
      ./fish
      ./starship
      ./bin
      ./zellij
      ./nebula.nix
      ./syncthing.nix
      ({ lib, pkgs, ... }: {
        nixpkgs.config.allowUnfree = true;
        hardware.enableRedistributableFirmware = true;
        users.defaultUserShell = pkgs.fish;
        hardware.bluetooth.enable = true;
        services.blueman.enable = true;
        services.upower.enable = true;

        networking.networkmanager.enable = true;

        services.avahi = {
          enable = true;
          nssmdns4 = true;
          denyInterfaces = [ "docker0" "br-+" "veth+" "nebula1" ];
          publish = {
            enable = true;
            addresses = true;
          };
        };

        # lan-mouse KVM — listen on port 4343 (4242 used by nebula)
        networking.firewall.allowedTCPPorts = [ 4343 ];
        networking.firewall.allowedUDPPorts = [ 4343 ];

        systemd.user.services.lan-mouse = {
          description = "lan-mouse KVM";
          after = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse --daemon";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };

        time.timeZone = "America/Edmonton";
        time.hardwareClockInLocalTime = true;

        programs.gnupg.agent = {
          enable = true;
          pinentryPackage = pkgs.pinentry-curses;
        };

        security.polkit.enable = true;
        security.rtkit.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          pulse.enable = true;
        };

        # ── Shells ────────────────────────────────────────────────────────
        programs.bash.enable = true;

        programs.fish = {
          enable = true;
          # Registers fish in /etc/shells so it can be a login shell.
        };

        # programs.nushell is a home-manager option, not a NixOS one.
        # nushell is installed via environment.systemPackages below.

        # ── SSH ───────────────────────────────────────────────────────────
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        # ── Packages ──────────────────────────────────────────────────────
        environment.systemPackages = with pkgs; [
          claude-code
          # Shell extras
          fish
          nushell
          bash
          keepassxc
          pass
          gnupg
          pinentry-curses
          # SSH tooling
          openssh
        ];

        fonts.fontconfig.enable = true;
        fonts.fontDir.enable = true;
        fonts.packages = with pkgs; [
          nerd-fonts.fira-code
          nerd-fonts.inconsolata
          nerd-fonts.iosevka
          nerd-fonts.ubuntu
          noto-fonts
          noto-fonts-color-emoji
          inconsolata
          iosevka
        ];

        hardware.graphics.enable = true;
      })
    ];

    surfaceModules = commonModules ++ [
      nixos-hardware.nixosModules.microsoft-surface-pro-intel
      ({ lib, pkgs, ... }: {
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
        # post-resume.target is reached after resume completes.
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

        # Btrfs swapfile for hibernate — set NOCOW before creation
        system.activationScripts.swapNocow = {
          text = ''
            if [ -d /swap ]; then
              ${pkgs.e2fsprogs}/bin/chattr +C /swap 2>/dev/null || true
            fi
          '';
        };
        swapDevices = [{ device = "/swap/swapfile"; size = 32 * 1024; }];

        environment.systemPackages = with pkgs; [ powertop lm_sensors ];
      })
    ];

    laptopModules = commonModules ++ [
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-gpu-amd
      ({ lib, pkgs, ... }: {
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
      })
    ];

    asusModules = commonModules ++ [
      nixos-hardware.nixosModules.common-cpu-intel
      nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
      nixos-hardware.nixosModules.common-pc-laptop
      nixos-hardware.nixosModules.common-pc-laptop-ssd
      ({ lib, pkgs, config, ... }: {
        # Asus TUF Gaming F16 (FX608JM) — Intel Raptor Lake + NVIDIA RTX
        services.asusd.enable = true;
        services.supergfxd.enable = true;

        # Boot in integrated mode (iGPU only) for battery life.
        # Switch at runtime with: supergfxctl -m Hybrid  (requires logout)
        environment.etc."supergfxd.conf".text = builtins.toJSON {
          mode = "Integrated";
          vfio_enable = false;
          vfio_save = false;
          always_reboot = false;
          no_logind = false;
          logout_timeout_s = 180;
          hotplug_type = "None";
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
        boot.kernelParams = [ "nvidia_drm.modeset=1" "nvidia_drm.fbdev=1" ];

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
        powerManagement.powertop.enable = true;
        environment.systemPackages = with pkgs; [ powertop lm_sensors ];
      })
    ];

    desktopModules = commonModules ++ [
      ({ pkgs, ... }: {
        hardware.amdgpu.initrd.enable = true;
        environment.systemPackages = with pkgs; [ lm_sensors ];
      })
    ];
  in {
    nixosConfigurations.surface-iso = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit hyprland hyprgrass; };
      modules = surfaceModules ++ [
        ./iso-packages.nix
        ({ lib, pkgs, modulesPath, ... }: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];

          environment.systemPackages = [ disko.packages.x86_64-linux.disko ];

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
          };

          system.activationScripts.userDirs = {
            deps = [ "users" ];
            text = ''
              mkdir -p /home/lakin/.config/hyprpanel
              mkdir -p /home/lakin/.config/hyprshell
              chown -R lakin:users /home/lakin
            '';
          };

          isoImage.squashfsCompression = "gzip -Xcompression-level 1";
          isoImage.contents = [
            { source = self; target = "/flake"; }
            { source = "${self}/INSTALL.md"; target = "/INSTALL.md"; }
          ];
        })
      ];
    };

    nixosConfigurations.surface = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit hyprland hyprgrass; };
      modules = surfaceModules ++ [
        disko.nixosModules.disko
        ./disko-config.nix
        ./iso-packages.nix
        ({ pkgs, ... }: {
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          networking.hostName = "harry";

          system.activationScripts.lanMouseConfig = {
            deps = [ "users" ];
            text = ''
              mkdir -p /home/lakin/.config/lan-mouse
              cat > /home/lakin/.config/lan-mouse/config.toml << 'EOF'
port = 4343

[top]
hostname = "trunkie.local"
ips = ["192.168.50.15"]
port = 4343
activate_on_startup = true
EOF
              chown -R lakin:users /home/lakin/.config/lan-mouse
            '';
          };

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
            initialPassword = "changeme";
          };

          system.stateVersion = "24.11";
        })
      ];
    };

    nixosConfigurations.laptop-iso = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit hyprland; hyprgrass = null; };
      modules = laptopModules ++ [
        ./iso-packages.nix
        ({ lib, pkgs, modulesPath, ... }: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];

          environment.systemPackages = [ disko.packages.x86_64-linux.disko ];

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
          };

          system.activationScripts.userDirs = {
            deps = [ "users" ];
            text = ''
              mkdir -p /home/lakin/.config/hyprpanel
              mkdir -p /home/lakin/.config/hyprshell
              chown -R lakin:users /home/lakin
            '';
          };

          isoImage.squashfsCompression = "gzip -Xcompression-level 1";
          isoImage.contents = [
            { source = self; target = "/flake"; }
            { source = "${self}/INSTALL.md"; target = "/INSTALL.md"; }
          ];
        })
      ];
    };

    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit hyprland; hyprgrass = null; };
      modules = laptopModules ++ [
        disko.nixosModules.disko
        ./disko-config.nix
        ./iso-packages.nix
        ({ pkgs, ... }: {
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          networking.hostName = "laptop";

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
            initialPassword = "changeme";
          };

          system.stateVersion = "24.11";
        })
      ];
    };

    nixosConfigurations.desktop-iso = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit hyprland; hyprgrass = null; };
      modules = desktopModules ++ [
        ./iso-packages.nix
        ({ lib, pkgs, modulesPath, ... }: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];

          environment.systemPackages = [ disko.packages.x86_64-linux.disko ];

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
          };

          system.activationScripts.userDirs = {
            deps = [ "users" ];
            text = ''
              mkdir -p /home/lakin/.config/hyprpanel
              mkdir -p /home/lakin/.config/hyprshell
              chown -R lakin:users /home/lakin
            '';
          };

          isoImage.squashfsCompression = "gzip -Xcompression-level 1";
          isoImage.contents = [
            { source = self; target = "/flake"; }
            { source = "${self}/INSTALL.md"; target = "/INSTALL.md"; }
          ];
        })
      ];
    };

    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit hyprland; hyprgrass = null; };
      modules = desktopModules ++ [
        disko.nixosModules.disko
        ./disko-config.nix
        ./iso-packages.nix
        ({ pkgs, ... }: {
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          networking.hostName = "desktop";

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
            initialPassword = "changeme";
          };

          system.stateVersion = "24.11";
        })
      ];
    };

    nixosConfigurations.asus-tuf-iso = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit hyprland;
        hyprgrass = null;
        hyprHostConfig = ''
          # Asus TUF F16 — 2560x1600 display, 1.25x scale
          monitor=eDP-1,preferred,auto,1.25
          monitor=,preferred,auto,1
        '';
        hyprWallpaper = ./hypr/wallpaper-roach.jpg;
      };
      modules = asusModules ++ [
        ./iso-packages.nix
        ({ lib, pkgs, modulesPath, ... }: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];

          environment.systemPackages = [ disko.packages.x86_64-linux.disko ];

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
          };

          system.activationScripts.userDirs = {
            deps = [ "users" ];
            text = ''
              mkdir -p /home/lakin/.config/hyprpanel
              mkdir -p /home/lakin/.config/hyprshell
              chown -R lakin:users /home/lakin
            '';
          };

          isoImage.squashfsCompression = "gzip -Xcompression-level 1";
          isoImage.contents = [
            { source = self; target = "/flake"; }
            { source = "${self}/INSTALL.md"; target = "/INSTALL.md"; }
          ];
        })
      ];
    };

    nixosConfigurations.asus-tuf = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit hyprland;
        hyprgrass = null;
        hyprHostConfig = ''
          # Asus TUF F16 — 2560x1600 display, 1.25x scale
          monitor=eDP-1,preferred,auto,1.25
          monitor=,preferred,auto,1
        '';
        hyprWallpaper = ./hypr/wallpaper-roach.jpg;
      };
      modules = asusModules ++ [
        disko.nixosModules.disko
        ./disko-config-asus-tuf.nix
        ./iso-packages.nix
        ({ pkgs, ... }: {
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          networking.hostName = "roach";

          users.users.lakin = {
            isNormalUser = true;
            home = "/home/lakin";
            createHome = true;
            extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
            initialPassword = "changeme";
          };

          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
