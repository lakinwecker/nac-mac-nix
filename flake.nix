{
  description = "Lakin's Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Own input so `nix flake update nixpkgs-claude` bumps claude-code alone,
    # without dragging the kernel and mesa along with it.
    nixpkgs-claude.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Hyprland and its three plugins move together. v0.56.1 is the newest
    # release with a published pin for all three — do not bump unless every
    # plugin has one for the target release.
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.56.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprgrass = {
      url = "github:horriblename/hyprgrass/hl-0.56.1";
      inputs.hyprland.follows = "hyprland";
    };
    # From the plugin's hyprpm.toml commit_pins row for Hyprland v0.56.1. Do
    # NOT pin the commit that *adds* a newer row — it tracks Hyprland main.
    hypr-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors/f5ba36c7622098b53bf62ddb8ddf03b914abbdf8";
      inputs.hyprland.follows = "hyprland";
    };
    # Community fork; upstream hyprexpo has no 0.56 pin.
    hyprexpo-src = {
      url = "github:sandwichfarm/hyprexpo/v0.56.1+3";
      flake = false;
    };
    devenv.url = "github:cachix/devenv/v2.3.1";
  };

  outputs = { self, nixpkgs, nixpkgs-claude, devenv, nixos-hardware, disko, hyprland, hyprgrass, hypr-dynamic-cursors, hyprexpo-src, ... }:
  let
    machines = import ./machines.nix;

    devenvOverlay = { ... }: {
      nixpkgs.overlays = [
        (_final: prev: {
          devenv = devenv.packages.${prev.stdenv.hostPlatform.system}.default;
        })
      ];
    };

    claudeOverlay = { ... }: {
      nixpkgs.overlays = [
        (_final: prev: {
          # Imported rather than legacyPackages: this is a separate pkgs
          # instance, so common/user.nix's allowUnfree does not reach it.
          claude-code = (import nixpkgs-claude {
            inherit (prev.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          }).claude-code;
        })
      ];
    };

    commonModules = [ ./common devenvOverlay claudeOverlay ];
    desktopModule = { hyprland = ./hypr; xfce = ./xfce; gnome = ./gnome; };

    mkHostModules = name: m:
      commonModules
      ++ map (hw: nixos-hardware.nixosModules.${hw}) (m.hardware or [])
      ++ [ desktopModule.${m.desktop} ]
      ++ [ ./hosts/${name} ];

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
          # 511 MB ESP, ~75 MB per generation; uncapped it fills /boot mid-switch.
          boot.loader.systemd-boot.configurationLimit = 5;
          boot.loader.efi.canTouchEfiVariables = true;

          # quiet/splash + low log level keep the text scroll off the splash.
          boot.plymouth.enable = true;
          boot.kernelParams = [ "quiet" "splash" "rd.udev.log_level=3" "udev.log_priority=3" ];
          boot.consoleLogLevel = 0;
          boot.initrd.verbose = false;

          # A stuck user-session unit plus the default 90s timeout wedges
          # reboot for minutes.
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

    # Guards against hyprlang-era hyprctl spellings, which fail silently under
    # the Lua config. See hypr/scripts/hypr-lua.sh.
    checks.x86_64-linux.hyprctl-lua =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.runCommand "hyprctl-lua-check" { nativeBuildInputs = [ pkgs.bash pkgs.gnugrep pkgs.findutils ]; } ''
        bash ${./hypr/lint-hyprctl.sh} ${./.}
        touch $out
      '';
  };
}
