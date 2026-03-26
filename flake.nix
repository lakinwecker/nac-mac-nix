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
      # Pinned to match hyprgrass compatibility (0.8.2)
      url = "github:hyprwm/Hyprland/70cdd819e4bee3c4dcea6961d32e61e6afe4eeb0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
        ];

        systemd.sleep.settings.Sleep = {
          AllowSuspend = "yes";
          SuspendState = "freeze";
        };

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
      specialArgs = { inherit hyprland hyprgrass; };
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
      specialArgs = { inherit hyprland hyprgrass; };
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
      specialArgs = { inherit hyprland hyprgrass; };
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
      specialArgs = { inherit hyprland hyprgrass; };
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
  };
}
