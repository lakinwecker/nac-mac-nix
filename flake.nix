{
  description = "Lakin's Machines";

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
    # ── Module lists ────────────────────────────────────────────────
    commonModules = [ ./common ];

    harryModules = commonModules ++ [
      nixos-hardware.nixosModules.microsoft-surface-pro-intel
      ./hypr
      ./hosts/harry
    ];

    sebbersModules = commonModules ++ [
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-gpu-amd
      ./hypr
      ./hosts/sebbers
    ];

    trunkieModules = commonModules ++ [
      ./hypr
      ./hosts/trunkie
    ];

    roachModules = commonModules ++ [
      nixos-hardware.nixosModules.common-cpu-intel
      nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
      nixos-hardware.nixosModules.common-pc-laptop
      nixos-hardware.nixosModules.common-pc-laptop-ssd
      ./hypr
      ./hosts/roach
    ];

    cornfieldModules = commonModules ++ [
      nixos-hardware.nixosModules.common-cpu-intel
      nixos-hardware.nixosModules.common-pc-laptop
      nixos-hardware.nixosModules.common-pc-laptop-ssd
      ./xfce
      ./hosts/cornfield
    ];

    # ── specialArgs per host ─────────────────────────────────────────
    defaultSpecialArgs = { username = "lakin"; inherit hyprland; hyprgrass = null; ollamaCuda = false; };
    harrySpecialArgs = { username = "lakin"; inherit hyprland hyprgrass; };
    roachSpecialArgs = defaultSpecialArgs // {
      ollamaCuda = true;
      hyprHostConfig = ''
        # Asus TUF F16 — 2560x1600 display, 1.25x scale
        monitor=eDP-1,preferred,auto,1.25
        monitor=,preferred,auto,1

        # Swap Alt and Super to match Mac-style layout
        input {
            kb_options = altwin:swap_lalt_lwin
        }
      '';
      hyprWallpaper = ./hypr/wallpaper-roach.jpg;
    };
    cornfieldSpecialArgs = {
      username = "clown";
      hyprland = null;
      hyprgrass = null;
      ollamaCuda = false;
      xfceWallpaper = ./xfce/wallpaper-cornfield.jpeg;
      xfceAvatar = ./xfce/avatar-cornfield.jpg;
    };

    # ── Helpers ───────────────────────────────────────────────────────
    mkIso = {
      hostModules,
      specialArgs ? defaultSpecialArgs,
      hostname,
    }: nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      modules = hostModules ++ [
        ./iso-packages.nix
        ({ modulesPath, username, ... }: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];

          networking.hostName = hostname;

          environment.systemPackages = [ disko.packages.x86_64-linux.disko ];

          users.users.${username} = {
            isNormalUser = true;
            home = "/home/${username}";
            createHome = true;
            extraGroups = [ "wheel" "video" "audio" "docker" ];
          };

          system.activationScripts.userDirs = {
            deps = [ "users" ];
            text = ''
              install -d -o ${username} -g users /home/${username}/.config
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

    mkInstalled = {
      hostModules,
      specialArgs ? defaultSpecialArgs,
      hostname,
      diskoConfig ? ./disko-config.nix,
      extraModules ? [],
    }: nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      modules = hostModules ++ [
        disko.nixosModules.disko
        diskoConfig
        ./iso-packages.nix
        ({ username, ... }: {
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          networking.hostName = hostname;

          users.users.${username} = {
            isNormalUser = true;
            home = "/home/${username}";
            createHome = true;
            extraGroups = [ "wheel" "video" "audio" "docker" ];
            initialPassword = "changeme";
          };

          system.stateVersion = "24.11";
        })
      ] ++ extraModules;
    };

  in {
    nixosConfigurations = {
      # ── harry (Surface Pro 9) ─────────────────────────────────────
      harry-iso = mkIso {
        hostModules = harryModules;
        specialArgs = harrySpecialArgs;
        hostname = "harry";
      };
      harry = mkInstalled {
        hostModules = harryModules;
        specialArgs = harrySpecialArgs;
        hostname = "harry";
        extraModules = [
          ({ username, ... }: {
            system.activationScripts.lanMouseConfig = {
              deps = [ "users" ];
              text = ''
                install -d -o ${username} -g users /home/${username}/.config
                install -d -o ${username} -g users /home/${username}/.config/lan-mouse
                cat > /home/${username}/.config/lan-mouse/config.toml << 'EOF'
port = 4343

[top]
hostname = "trunkie.local"
ips = ["192.168.50.15"]
port = 4343
activate_on_startup = true
EOF
                chown ${username}:users /home/${username}/.config/lan-mouse/config.toml
              '';
            };
          })
        ];
      };

      # ── sebbers (AMD laptop) ──────────────────────────────────────
      sebbers-iso = mkIso {
        hostModules = sebbersModules;
        hostname = "sebbers";
      };
      sebbers = mkInstalled {
        hostModules = sebbersModules;
        hostname = "sebbers";
      };

      # ── trunkie (Threadripper desktop) ──────────────────────────
      trunkie-iso = mkIso {
        hostModules = trunkieModules;
        hostname = "trunkie";
      };
      trunkie = mkInstalled {
        hostModules = trunkieModules;
        hostname = "trunkie";
      };

      # ── roach (Asus TUF F16) ────────────────────────────────────
      roach-iso = mkIso {
        hostModules = roachModules;
        specialArgs = roachSpecialArgs;
        hostname = "roach";
      };
      roach = mkInstalled {
        hostModules = roachModules;
        specialArgs = roachSpecialArgs;
        hostname = "roach";
        diskoConfig = ./hosts/roach/disko-config.nix;
      };

      # ── cornfield (ThinkPad T460) ──────────────────────────────────
      cornfield-iso = mkIso {
        hostModules = cornfieldModules;
        specialArgs = cornfieldSpecialArgs;
        hostname = "cornfield";
      };
      cornfield = mkInstalled {
        hostModules = cornfieldModules;
        specialArgs = cornfieldSpecialArgs;
        hostname = "cornfield";
      };
    };
  };
}
