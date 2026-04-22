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
    # ── Machine registry ────────────────────────────────────────────
    machines = import ./machines.nix;
    commonModules = [ ./common ];
    desktopModule = { hyprland = ./hypr; xfce = ./xfce; gnome = ./gnome; };

    # Build the NixOS module list for a machine.
    mkHostModules = name: m:
      commonModules
      ++ map (hw: nixos-hardware.nixosModules.${hw}) (m.hardware or [])
      ++ [ desktopModule.${m.desktop} ]
      ++ [ ./hosts/${name} ];

    # Build specialArgs from a machine's registry entry.
    mkSpecialArgs = _name: m:
      {
        username   = m.username or "lakin";
        hyprland   = if m.desktop == "hyprland" then hyprland else null;
        hyprgrass  = if (m.hyprgrass or false) then hyprgrass else null;
        ollamaCuda = m.ollamaCuda or false;
      }
      // (if m.desktop == "hyprland" then {
        hyprHostConfig = m.hyprHostConfig or "";
        hyprWallpaper  = m.hyprWallpaper or ./hypr/wallpaper.jpg;
      } else {})
      // (if m.desktop == "xfce" then {
        xfceWallpaper = m.xfceWallpaper or null;
        xfceAvatar    = m.xfceAvatar or null;
      } else {});

    # Generate {<name>-iso, <name>} configs for one machine.
    mkMachineConfigs = name: m: let
      hostModules = mkHostModules name m;
      specialArgs = mkSpecialArgs name m;
    in {
      "${name}-iso" = mkIso {
        inherit hostModules specialArgs;
        hostname = name;
      };
      ${name} = mkInstalled {
        inherit hostModules specialArgs;
        hostname     = name;
        diskoConfig  = m.diskoConfig or ./disko-config.nix;
        extraModules = m.extraModules or [];
      };
    };

    # ── Helpers (unchanged) ─────────────────────────────────────────
    defaultSpecialArgs = mkSpecialArgs "" { desktop = "hyprland"; };

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
    nixosConfigurations = nixpkgs.lib.concatMapAttrs mkMachineConfigs machines;
  };
}
