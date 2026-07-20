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
      # Pinned to tagged release — bump in lockstep with hyprgrass/hypr-dynamic-cursors.
      url = "github:hyprwm/Hyprland/v0.55.4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # hyprgrass is Surface-only (touchscreen gestures). Tracks main; the
    # surface configs are the only ones that pass it through to hypr/default.nix.
    hyprgrass = {
      url = "github:horriblename/hyprgrass/d094a3e62f6ecaeb41515982d3e13edefaf8a4e7";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-next = {
      url = "github:hyprwm/Hyprland/v0.56.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hypr-dynamic-cursors = {
      # Pinned to 0.55.4-compatible commit — bump in lockstep with hyprland.
      url = "github:VirtCode/hypr-dynamic-cursors/da447486c84e0be81f2cdd208af1ef92469f0a88";
      inputs.hyprland.follows = "hyprland";
    };
    hypr-dynamic-cursors-next = {
      url = "github:VirtCode/hypr-dynamic-cursors/5ef778ea151deb3573383d13d6e1cf7eed7336e1";
      inputs.hyprland.follows = "hyprland-next";
    };
    # Community-maintained hyprexpo fork (workspace overview). Pinned to v0.55.4
    # release — bump in lockstep with hyprland.
    hyprexpo-src = {
      url = "github:sandwichfarm/hyprexpo/v0.55.4";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, disko, hyprland, hyprland-next, hyprgrass, hypr-dynamic-cursors, hypr-dynamic-cursors-next, hyprexpo-src, ... }:
  let
    # ── Machine registry ────────────────────────────────────────────
    machines = import ./machines.nix;
    commonModules = [ ./common ];
    desktopModule = { hyprland = ./hypr; xfce = ./xfce; gnome = ./gnome; };

    hyprlandChannels = {
      stable = {
        hyprland = hyprland;
        hyprgrass = hyprgrass;
        hyprDynamicCursors = hypr-dynamic-cursors;
        hyprexpoSrc = hyprexpo-src;
      };
      next = {
        hyprland = hyprland-next;
        hyprgrass = throw "hyprgrass has no pin compatible with the 'next' Hyprland channel; keep this host on 'stable' or add a hyprgrass-next input.";
        hyprDynamicCursors = hypr-dynamic-cursors-next;
        hyprexpoSrc = null;
      };
    };

    # Build the NixOS module list for a machine.
    mkHostModules = name: m:
      commonModules
      ++ map (hw: nixos-hardware.nixosModules.${hw}) (m.hardware or [])
      ++ [ desktopModule.${m.desktop} ]
      ++ [ ./hosts/${name} ];

    # Build specialArgs from a machine's registry entry.
    mkSpecialArgs = _name: m:
      let channel = hyprlandChannels.${m.hyprlandChannel or "stable"};
      in {
        username   = m.username or "lakin";
        hyprland   = if m.desktop == "hyprland" then channel.hyprland else null;
        hyprgrass  = if (m.hyprgrass or false) then channel.hyprgrass else null;
        ollamaCuda = m.ollamaCuda or false;
        devTools   = m.devTools or true;
      }
      // (if m.desktop == "hyprland" then {
        hyprHostConfig = m.hyprHostConfig or "";
        hyprWallpaper  = m.hyprWallpaper or ./hypr/wallpaper.jpg;
        hyprDynamicCursorsMode = m.hyprDynamicCursorsMode or "none";
        inherit (channel) hyprDynamicCursors hyprexpoSrc;
        hyprIdleTimeouts       = m.hyprIdleTimeouts or {};
        hyprSuspendOnAc        = m.hyprSuspendOnAc or true;
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
            { source = "${self}/docs/install.md"; target = "/INSTALL.md"; }
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
