# machines.nix — one entry per host.
# To add a machine: add an entry here + create hosts/<name>/default.nix.
#
# Fields (all optional except `desktop`):
#   desktop        "hyprland" | "xfce" | "gnome"
#   username       default: "lakin"
#   hardware       list of nixos-hardware module name strings, default: []
#   hyprgrass      enable touch gestures (Surface), default: false
#   hyprHostConfig hyprland monitor/input config string, default: ""
#   hyprWallpaper  path to wallpaper, default: ./hypr/wallpaper.jpg
#   xfceWallpaper  path to wallpaper, default: null
#   xfceAvatar     path to avatar, default: null
#   ollamaCuda     enable CUDA ollama, default: false
#   diskoConfig    path to disko-config.nix, default: ./disko-config.nix
#   dualDrive      true if install needs --home-disk, default: false
#   extraModules   list of extra NixOS modules, default: []
{
  harry = {
    # Surface Pro 9 (Intel)
    desktop = "hyprland";
    hardware = [ "microsoft-surface-pro-intel" ];
    hyprgrass = true;
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

  sebbers = {
    # AMD laptop
    desktop = "hyprland";
    hardware = [ "common-cpu-amd" "common-gpu-amd" ];
    diskoConfig = ./hosts/sebbers/disko-config.nix;
    dualDrive = true;
    hyprHostConfig = ''
      # AMD laptop — 2560x1600@120Hz display, 1.25x scale
      monitor=eDP-1,2560x1600@120,auto,1.25
      monitor=,preferred,auto,1

      # Swap Alt and Super to match Mac-style layout
      input {
          kb_options = altwin:swap_lalt_lwin
      }
    '';
  };

  trunkie = {
    # Threadripper desktop
    desktop = "hyprland";
  };

  roach = {
    # Asus TUF F16 (Intel + NVIDIA)
    desktop = "hyprland";
    hardware = [ "common-cpu-intel" "common-gpu-nvidia-nonprime" "common-pc-laptop" "common-pc-laptop-ssd" ];
    diskoConfig = ./hosts/roach/disko-config.nix;
    dualDrive = true;
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

  souris = {
    # Dell XPS 13 9360 (Kaby Lake)
    desktop = "gnome";
    username = "souris";
    hardware = [ "dell-xps-13-9360" ];
  };

  cornfield = {
    # ThinkPad T460 (Skylake)
    desktop = "xfce";
    username = "clown";
    hardware = [ "common-cpu-intel" "common-pc-laptop" "common-pc-laptop-ssd" ];
    xfceWallpaper = ./xfce/wallpaper-cornfield.jpeg;
    xfceAvatar = ./xfce/avatar-cornfield.jpg;
  };
}
