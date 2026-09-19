# One entry per host. To add a machine: add an entry here + create
# hosts/<name>/default.nix. All fields optional except `desktop`.
#
#   desktop        "hyprland" | "xfce" | "gnome"
#   username       default "lakin"
#   hardware       nixos-hardware module names, default []
#   hyprgrass      touch gestures (Surface), default false
#   hyprHostConfig Lua appended to hypr/hyprland.lua, default ""
#   hyprWallpaper  default ./hypr/wallpaper.jpg
#   hyprDynamicCursorsMode  "none" (default) | "tilt" | "rotate" | "stretch"
#   hyprIdleTimeouts  seconds; dim/lock/dpms/suspend, defaults 181/300/600/900.
#                  suspend = 0 drops the suspend listener entirely.
#   hyprLockGrace  seconds hyprlock stays dismissible by any input, default 2
#   hyprSuspendOnAc  idle-suspend on mains power, default true
#   hyprHibernate  offer Hibernate in the power menu, default true
#   xfceWallpaper / xfceAvatar  default null
#   ghosttyOpacity 0.0-1.0, default 0.85
#   lanMouseCaptureBackend  default null (auto). "dummy" never opens an
#                  input-capture portal session, dodging the xdph fd leak that
#                  crashes the session bus (xdph#419). Avoid "layer-shell": it
#                  sticks modifiers and repeats keystrokes here.
#   ollamaAccel    "cpu" (default) | "cuda" | "rocm"
#   devTools       heavier dev modules (nvim, zellij, ollama, latex), default true
#   diskoConfig    default ./disko-config.nix
#   extraModules   default []
{
  harry = {
    # Surface Pro 9 (Intel)
    desktop = "hyprland";
    hardware = [ "microsoft-surface-pro-intel" ];
    hyprgrass = true;
    hyprHibernate = false;   # not configured on harry
    hyprHostConfig = ''
      -- Mac-style Alt/Super swap
      hl.config({
          input = {
              kb_options = "altwin:swap_lalt_lwin",

              tablet = {
                  output = "eDP-1",
              },
          },
      })
    '';
    extraModules = [
      ({ ... }: {
        # In /etc rather than ~/.config — see the note on trunkie.
        environment.etc."lan-mouse/config.toml".text = ''
          port = 4343

          # Required: peers not listed here are rejected at the DTLS handshake.
          [authorized_fingerprints]
          "44:bc:eb:83:d7:a3:e8:99:1c:57:e8:7b:4e:01:67:7a:f4:45:c2:64:9e:5a:e5:79:5b:ae:ba:23:58:fe:b7:6a" = "trunkie"

          # trunkie — above harry. The pre-0.11 [top]/[left] section form is
          # silently ignored; peers must be [[clients]] with a `position`.
          [[clients]]
          position = "top"
          hostname = "trunkie.local"
          ips = ["192.168.50.15"]
          port = 4343
          activate_on_startup = true
        '';
      })
    ];
  };

  gratch = {
    # AMD laptop
    desktop = "hyprland";
    hardware = [ "common-cpu-amd" "common-gpu-amd" "common-pc-laptop" "common-pc-laptop-ssd" ];
    diskoConfig = ./hosts/gratch/disko-config.nix;
    hyprDynamicCursorsMode = "tilt";
    hyprSuspendOnAc = false;
    hyprHostConfig = ''
      hl.monitor({ output = "eDP-1", mode = "2560x1600@120", position = "auto", scale = 1.25 })
      hl.monitor({ output = "",      mode = "preferred",     position = "auto", scale = 1 })

      -- Mac-style Alt/Super swap, laptop keyboard only
      hl.device({
          name = "at-translated-set-2-keyboard",
          kb_options = "altwin:swap_lalt_lwin,caps:backspace",
      })
    '';
  };

  trunkie = {
    # Threadripper 1950X desktop — AMD GPU, 64GB RAM
    desktop = "hyprland";
    hardware = [ "common-cpu-amd" "common-gpu-amd" "common-pc" "common-pc-ssd" ];
    diskoConfig = ./hosts/trunkie/disko-config.nix;
    # RX 6800 XT (gfx1030) is an officially supported ROCm target — no
    # rocmOverrideGfx needed.
    ollamaAccel = "rocm";
    # phoebe owns the keyboard/mouse here; trunkie only emulates.
    lanMouseCaptureBackend = "dummy";
    hyprWallpaper = ./hypr/wallpaper-trunkie.jpg;
    # Bright wallpaper washes out light-theme terminal text.
    ghosttyOpacity = 1.0;
    # dpms 310 lands as the 10s hyprLockGrace expires; sleep targets are masked
    # in hosts/trunkie.
    hyprIdleTimeouts = { suspend = 0; dpms = 310; };
    hyprLockGrace = 10;
    hyprHostConfig = ''
      hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@120", position = "0x0", scale = 1.25 })
      -- 1440p rotated 270deg, right of the 4K
      hl.monitor({ output = "DP-1", mode = "2560x1440@164", position = "3072x-420", scale = 1, transform = 3 })

      hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })

      -- HDMI-A-1 is KVM-shared. Disabling it explicitly makes Hyprland reflow
      -- windows instead of stranding them on a panel showing the other machine.
      -- Routed via kvm-monitor.sh because it must also restart lan-mouse; see
      -- the script.
      hl.bind("CTRL + SUPER + SHIFT + F9",  hl.dsp.exec_cmd("/etc/hypr/scripts/kvm-monitor.sh off HDMI-A-1"))
      hl.bind("CTRL + SUPER + SHIFT + F10", hl.dsp.exec_cmd("/etc/hypr/scripts/kvm-monitor.sh on HDMI-A-1"))

      -- By name, not monitor ID: the KVM hotplug above renumbers the IDs.
      hl.bind("SUPER + ALT + 1", hl.dsp.workspace.move({ monitor = "HDMI-A-1" }))
      hl.bind("SUPER + ALT + 2", hl.dsp.workspace.move({ monitor = "DP-1" }))
    '';
    extraModules = [
      ({ ... }: {
        # In /etc, not ~/.config: activation runs before /home is mounted, so a
        # home-written config is shadowed the moment /home mounts over it.
        # `position` is the peer's location relative to this host.
        environment.etc."lan-mouse/config.toml".text = ''
          port = 4343

          # Required: peers not listed here are rejected at the DTLS handshake.
          # `lan-mouse cli authorize-key` writes runtime state that this file
          # overwrites on every rebuild, so they must live here.
          [authorized_fingerprints]
          "8b:73:b1:29:df:1d:50:bb:92:ce:d1:15:21:ae:af:45:b8:a0:21:14:33:d1:ee:8e:14:50:0a:d9:ac:15:6f:6b" = "phoebe"

          # phoebe (Mac) — left of trunkie. ips is required: no mDNS in
          # lan-mouse's resolver (feschber/lan-mouse#234).
          [[clients]]
          position = "left"
          hostname = "phoebe.local"
          ips = ["192.168.50.52"]
          port = 4343
          # Must be false on a receive-only host: true makes lan-mouse seize
          # control and stream garbage to the peer under --capture-backend dummy.
          activate_on_startup = false
        '';
      })
    ];
  };

  roach = {
    # Asus TUF F16 (Intel + NVIDIA)
    desktop = "hyprland";
    hardware = [ "common-cpu-intel" "common-gpu-nvidia-nonprime" "common-pc-laptop" "common-pc-laptop-ssd" ];
    diskoConfig = ./hosts/roach/disko-config.nix;
    ollamaAccel = "cuda";   # 8GB VRAM
    hyprIdleTimeouts = { dim = 360; lock = 600; dpms = 1200; };
    hyprSuspendOnAc = false;
    hyprHostConfig = ''
      hl.monitor({ output = "eDP-1",     mode = "preferred",    position = "1920x0", scale = 1.25, vrr = 1 })
      hl.monitor({ output = "HDMI-A-2",  mode = "1920x1080@60", position = "0x0",    scale = 1 })
      hl.monitor({ output = "",          mode = "preferred",    position = "auto",   scale = 1 })

      -- Mac-style Alt/Super swap, laptop keyboard only
      hl.device({
          name = "at-translated-set-2-keyboard",
          kb_options = "altwin:swap_lalt_lwin,caps:backspace",
      })

      -- Kills fractional-scaling blur in Steam, the only XWayland client here.
      -- X11 apps then draw 1.25x too small unless told the scale themselves:
      -- Steam gets STEAM_FORCE_DESKTOPUI_SCALING in hosts/roach/default.nix.
      hl.config({
          xwayland = {
              force_zero_scaling = true,
          },
      })
    '';
    hyprWallpaper = ./hypr/wallpaper-roach.jpg;
    # phoebe captures; roach only emulates.
    lanMouseCaptureBackend = "dummy";
    extraModules = [
      ({ ... }: {
        # In /etc rather than ~/.config for the same reason as trunkie.
        environment.etc."lan-mouse/config.toml".text = ''
          port = 4343

          # Required: peers not listed here are rejected at the DTLS handshake.
          [authorized_fingerprints]
          "8b:73:b1:29:df:1d:50:bb:92:ce:d1:15:21:ae:af:45:b8:a0:21:14:33:d1:ee:8e:14:50:0a:d9:ac:15:6f:6b" = "phoebe"

          # phoebe (Mac) — right of roach. ips is required: no mDNS in
          # lan-mouse's resolver (feschber/lan-mouse#234).
          [[clients]]
          position = "right"
          hostname = "phoebe.local"
          ips = ["192.168.50.52"]
          port = 4343
          # Must be false on a receive-only host: true makes lan-mouse seize
          # control and stream garbage to the peer under --capture-backend dummy.
          activate_on_startup = false
        '';
      })
    ];
  };

  shrike = {
    # Dell XPS 16 9650 (Intel Panther Lake, Arc iGPU)
    desktop = "hyprland";
    hardware = [ "common-cpu-intel" "common-pc-laptop" "common-pc-laptop-ssd" ];
    hyprHostConfig = ''
      hl.monitor({ output = "eDP-1", mode = "2880x1800@60", position = "auto", scale = 1.5 })
      hl.monitor({ output = "",      mode = "preferred",    position = "auto", scale = 1 })

      -- Mac-style Alt/Super swap, laptop keyboard only
      hl.device({
          name = "at-translated-set-2-keyboard",
          kb_options = "altwin:swap_lalt_lwin",
      })

      -- The haptic pad has no physical click button.
      hl.config({
          input = {
              touchpad = {
                  tap_to_click = true,
              },
          },
      })
    '';
  };

  souris = {
    # Dell XPS 13 9370 (Kaby Lake R) — Anita's laptop
    desktop = "gnome";
    username = "anita";
    hardware = [ "dell-xps-13-9370" ];
    devTools = false;
    kagi = false;       # leave Firefox search alone
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
