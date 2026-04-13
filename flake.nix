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

        # Wifi via iwd; wired/everything-else via systemd-networkd.
        # Use impala or iwctl to manage wifi connections.
        networking.networkmanager.enable = false;
        networking.wireless.iwd = {
          enable = true;
          settings = {
            General.EnableNetworkConfiguration = true;
            Network.EnableIPv6 = true;
            Settings.AutoConnect = true;
          };
        };
        networking.useNetworkd = true;
        systemd.network.enable = true;
        # DHCP on any ethernet interface by default.
        systemd.network.networks."10-ethernet" = {
          matchConfig.Type = "ether";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
            MulticastDNS = true;
          };
        };

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
          # Hardware / system inspection
          inxi
          # Search / filesystem
          ripgrep
          fd
          du-dust
          jq
          # TUI productivity
          lazygit
          lazydocker
          yazi
          bluetuith
          impala
          glow
          # GitHub
          gh
          gh-dash
          # Kubernetes
          kubectl
          k9s
          kubernetes-helm
          # Databases
          pgcli
          lazysql
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

        # Bootstrap user config dirs and any "must exist" files for CLI
        # tools that refuse to run with a missing dir/file. Idempotent —
        # only creates what's missing, never clobbers user edits.
        system.activationScripts.userConfigBootstrap = {
          deps = [ "users" ];
          text = ''
            user=lakin
            home=/home/$user

            ensure_dir() {
              if [ ! -d "$1" ]; then
                mkdir -p "$1"
                chown $user:users "$1"
              fi
            }

            ensure_file() {
              if [ ! -e "$1" ]; then
                ensure_dir "$(dirname "$1")"
                touch "$1"
                chown $user:users "$1"
              fi
            }

            ensure_dir  "$home/.config"
            ensure_dir  "$home/.local/share"
            ensure_dir  "$home/.local/state"
            ensure_dir  "$home/.cache"

            # CLI tools that refuse to start with a missing config file
            ensure_file "$home/.config/lazygit/config.yml"

            # Tools that need their dir to exist but create their own files
            ensure_dir  "$home/.config/lazydocker"
            ensure_dir  "$home/.config/yazi"
            ensure_dir  "$home/.config/k9s"
            ensure_dir  "$home/.config/gh"
            ensure_dir  "$home/.config/gh-dash"
            ensure_dir  "$home/.config/btop"
            ensure_dir  "$home/.config/bluetuith"
            ensure_dir  "$home/.config/impala"
            ensure_dir  "$home/.config/pgcli"
            ensure_dir  "$home/.config/lazysql"
            ensure_dir  "$home/.config/zellij"
            ensure_dir  "$home/.config/nvim"
            ensure_dir  "$home/.config/fish"
            ensure_dir  "$home/.config/starship"
            ensure_dir  "$home/.config/ghostty"

            # Make sure the top-level home tree is owned correctly
            chown $user:users "$home/.config" "$home/.local" "$home/.local/share" "$home/.local/state" "$home/.cache" 2>/dev/null || true
          '';
        };
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
        # Systemd-based stage-1 gives an emergency shell on failure
        # (via systemd.debug-shell / systemd's default behavior) instead
        # of the scripted initrd's dead-end r/* prompt.
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

        boot.kernelParams = [
          "nvidia_drm.modeset=1"
          "nvidia_drm.fbdev=1"
          # Disable Intel GPU Panel Self-Refresh. PSR entry during
          # static screen + PSR exit on input events causes 50–500ms
          # stutters that look like keyboard+mouse+compositor freezing
          # together. Single most common Intel-laptop input-stutter fix.
          "i915.enable_psr=0"
          # NOTE: previously capped C-states with intel_idle.max_cstate=3
          # and processor.max_cstate=3, but processor.max_cstate=3 forced
          # the kernel into ACPI idle fallback (C1_ACPI/C2_ACPI/C3_ACPI)
          # with exit latencies *worse* than Intel's native C10. Both
          # removed so intel_idle can use its native, well-characterized
          # states.
        ];

        # Distribute hardware IRQs across cores instead of piling on CPU0.
        # Prevents input stutter when CPU0 is momentarily saturated.
        services.irqbalance.enable = true;

        # Disable USB autosuspend for HID (input) devices. USB mice and
        # keyboards don't meaningfully save power from autosuspend, but
        # the first event after an idle window incurs a 100–500ms wake
        # penalty that shows up as "mouse froze for a moment."
        services.udev.extraRules = ''
          # USB HID (bInterfaceClass 03) — disable autosuspend
          ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
          # Also target the parent device for class-03 children
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

            CPU_BOOST_ON_BAT = 0;
            CPU_HWP_DYN_BOOST_ON_BAT = 0;
            RUNTIME_PM_ON_BAT = "auto";
            # USB autosuspend stays ON for non-HID devices; the udev
            # rule above whitelists mice/keyboards back to "on".
            USB_AUTOSUSPEND = 1;
            WIFI_PWR_ON_BAT = "on";
            # "default" instead of "powersupersave" — the latter enables
            # L1.2 substate with ~10ms+ exit latency per PCIe hop, a
            # known source of periodic input stutter on Asus boards.
            PCIE_ASPM_ON_BAT = "default";
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
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
            extraGroups = [ "wheel" "video" "audio" "docker" ];
            initialPassword = "changeme";
          };

          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
