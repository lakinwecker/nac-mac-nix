{
  description = "Lakin's Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ── Hyprland and its three out-of-tree plugins ──────────────────
    #
    # All four move together, and the release they can move *to* is dictated by
    # the plugins, not by Hyprland. v0.56.1 is the newest release with a pin
    # published for every one of them:
    #
    #   Hyprland              v0.56.1
    #   hyprgrass             hl-0.56.1        (newest tag; nothing for 0.56.2)
    #   hyprexpo (fork)       v0.56.1+3        (newest tag; nothing for 0.56.2)
    #   hypr-dynamic-cursors  f5ba36c7         (hyprpm.toml pin for 0.56.1)
    #
    # v0.56.2 exists and dynamic-cursors covers it, but hyprgrass and hyprexpo
    # do not — moving there costs harry's touch gestures and the overview on
    # every host. That is why the fleet sits one release back rather than on
    # the newest tag. Before bumping, check that all three plugins have
    # published a pin for the target release; if any has not, do not bump.
    #
    # 0.56.1 also carries xdg-desktop-portal-hyprland v1.4.0+1, which has the
    # InputCapture portal lan-mouse needs on trunkie (added in 1.4.0).
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.56.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # hyprgrass is Surface-only (touchscreen gestures). harry is the only host
    # that passes it through to hypr/default.nix.
    hyprgrass = {
      url = "github:horriblename/hyprgrass/hl-0.56.1";
      inputs.hyprland.follows = "hyprland";
    };
    # Taken from the plugin's own hyprpm.toml commit_pins table, which maps a
    # Hyprland commit to the plugin commit that builds against it:
    #   ["5c9377c…" (Hyprland v0.56.1), "f5ba36c…"]
    # Do NOT pin the commit that *adds* a newer table row — its own tree tracks
    # Hyprland main and wants headers that do not exist in a tagged release.
    hypr-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors/f5ba36c7622098b53bf62ddb8ddf03b914abbdf8";
      inputs.hyprland.follows = "hyprland";
    };
    # Community-maintained hyprexpo fork (workspace overview).
    hyprexpo-src = {
      url = "github:sandwichfarm/hyprexpo/v0.56.1+3";
      flake = false;
    };
    devenv.url = "github:cachix/devenv/v2.3";
  };

  outputs = { self, nixpkgs, devenv, nixos-hardware, disko, hyprland, hyprgrass, hypr-dynamic-cursors, hyprexpo-src, ... }:
  let
    # ── Machine registry ────────────────────────────────────────────
    machines = import ./machines.nix;

    devenvOverlay = { ... }: {
      nixpkgs.overlays = [
        (_final: prev: {
          devenv = devenv.packages.${prev.stdenv.hostPlatform.system}.default;
        })
      ];
    };

    commonModules = [ ./common devenvOverlay ];
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
        ollamaAccel = m.ollamaAccel or "cpu";
        devTools   = m.devTools or true;
        ghosttyOpacity = m.ghosttyOpacity or 0.85;
        lanMouseCaptureBackend = m.lanMouseCaptureBackend or null;
        kagi       = m.kagi or true;
      }
      // (if m.desktop == "hyprland" then {
        hyprHostConfig = m.hyprHostConfig or "";
        hyprWallpaper  = m.hyprWallpaper or ./hypr/wallpaper.jpg;
        hyprDynamicCursorsMode = m.hyprDynamicCursorsMode or "none";
        hyprDynamicCursors = hypr-dynamic-cursors;
        hyprexpoSrc = hyprexpo-src;
        hyprIdleTimeouts       = m.hyprIdleTimeouts or {};
        hyprSuspendOnAc        = m.hyprSuspendOnAc or true;
        hyprLockGrace          = m.hyprLockGrace or 2;
        hyprHibernate          = m.hyprHibernate or true;
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
            extraGroups = [ "wheel" "video" "audio" "docker" "networkmanager" ];
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
          # The ESP is only 511 MB and each generation costs ~75 MB (kernel +
          # initrd), so cap retained generations — without this it keeps every
          # generation and eventually fills /boot mid-switch ("No space left").
          boot.loader.systemd-boot.configurationLimit = 5;
          boot.loader.efi.canTouchEfiVariables = true;

          # Graphical boot splash. Plymouth runs on whatever initrd the host
          # uses (systemd-initrd where enabled, classic otherwise); the quiet
          # params + low console log level suppress the text scroll so the
          # splash isn't stepped on. kernelParams merges with per-host params.
          boot.plymouth.enable = true;
          boot.kernelParams = [ "quiet" "splash" "rd.udev.log_level=3" "udev.log_priority=3" ];
          boot.consoleLogLevel = 0;
          boot.initrd.verbose = false;

          # Shutdown-hang mitigation. A user-session unit sometimes fails to
          # stop, and the default 90s stop timeout (hit potentially twice)
          # leaves reboot wedged for minutes. Cap it so a stuck unit is killed
          # in 15s and the machine actually powers down.
          systemd.settings.Manager.DefaultTimeoutStopSec = "15s";
          systemd.user.settings.Manager.DefaultTimeoutStopSec = "15s";

          networking.hostName = hostname;

          users.users.${username} = {
            isNormalUser = true;
            home = "/home/${username}";
            createHome = true;
            extraGroups = [ "wheel" "video" "audio" "docker" "networkmanager" ];
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
