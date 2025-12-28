{
  description = "NixOS Surface Pro 9 installer ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, hyprland, hyprgrass, ... }:
    let
      system = "x86_64-linux";
    in {
    nixosConfigurations.surface-iso = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit hyprland hyprgrass; };
      modules = [
        nixos-hardware.nixosModules.microsoft-surface-pro-intel
        ./iso-packages.nix
        ./hypr
        ./kitty
        ({ lib, pkgs, modulesPath, ... }: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];

          boot.supportedFilesystems.zfs = lib.mkForce false;
          boot.kernelPatches = [{
            name = "disable-rust";
            patch = null;
            structuredExtraConfig = { RUST = lib.mkForce lib.kernel.no; };
          }];

          nixpkgs.config.allowUnfree = true;
          hardware.enableRedistributableFirmware = true;
          services.iptsd.enable = true;

          networking.networkmanager.enable = true;
          networking.wireless.enable = false;

          security.polkit.enable = true;
          security.rtkit.enable = true;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };

          fonts.fontconfig.enable = true;
          fonts.fontDir.enable = true;
          fonts.packages = with pkgs; [
            nerd-fonts.fira-code
            noto-fonts
            noto-fonts-color-emoji
          ];

          hardware.graphics.enable = true;

          system.activationScripts.configOwnership = ''
            chown -R nixos:users /home/nixos/.config
          '';

          isoImage.squashfsCompression = "gzip -Xcompression-level 1";
        })
      ];
    };
  };
}
