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
#   hyprDynamicCursorsMode
#                  hypr-dynamic-cursors simulation mode (shake-to-find is
#                  always on). One of "none" | "tilt" | "rotate" | "stretch"
#                  (stretch = comic squash/stretch). Default: "none".
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
    hyprHostConfig = ''
      # Swap Alt and Super to match Mac-style layout
      input {
          kb_options = altwin:swap_lalt_lwin
      }
    '';
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

  gratch = {
    # AMD laptop
    desktop = "hyprland";
    hardware = [ "common-cpu-amd" "common-gpu-amd" "common-pc-laptop" "common-pc-laptop-ssd" ];
    diskoConfig = ./hosts/gratch/disko-config.nix;
    dualDrive = true;
    hyprDynamicCursorsMode = "tilt";
    hyprHostConfig = ''
      # AMD laptop — 2560x1600@120Hz display, 1.25x scale
      monitor=eDP-1,2560x1600@120,auto,1.25
      monitor=,preferred,auto,1

      # Swap Alt and Super to match Mac-style layout (laptop keyboard only)
      device {
          name = at-translated-set-2-keyboard
          kb_options = altwin:swap_lalt_lwin,caps:backspace
      }
    '';
  };

  trunkie = {
    # Threadripper 1950X desktop — AMD GPU, 64GB RAM
    # 4-disk btrfs RAID1: root mirror (2x224G) + home mirror (1.9T + 2T)
    desktop = "hyprland";
    hardware = [ "common-cpu-amd" "common-gpu-amd" "common-pc" "common-pc-ssd" ];
    diskoConfig = ./hosts/trunkie/disko-config.nix;
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

      # Swap Alt and Super to match Mac-style layout (laptop keyboard only)
      device {
          name = at-translated-set-2-keyboard
          kb_options = altwin:swap_lalt_lwin,caps:backspace
      }
    '';
    hyprWallpaper = ./hypr/wallpaper-roach.jpg;
  };

  shrike = {
    # Dell XPS 16 9650 (2026, Intel Panther Lake — Core Ultra X9 388H, Arc iGPU)
    # Temporary install to test before going back to Ubuntu.
    desktop = "hyprland";
    hardware = [ "common-cpu-intel" "common-pc-laptop" "common-pc-laptop-ssd" ];
    hyprHostConfig = ''
      # Dell XPS 16 — 16" OLED 2880x1800 touch, 1.5x scale
      monitor=eDP-1,2880x1800@60,auto,1.5
      monitor=,preferred,auto,1

      # Swap Alt and Super to match Mac-style layout (laptop keyboard only)
      device {
          name = at-translated-set-2-keyboard
          kb_options = altwin:swap_lalt_lwin
      }

      # Enable tap-to-click — haptic pad has no physical click button
      input {
          touchpad {
              tap-to-click=yes
          }
      }
    '';
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
