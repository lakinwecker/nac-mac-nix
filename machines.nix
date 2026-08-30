# machines.nix — one entry per host.
# To add a machine: add an entry here + create hosts/<name>/default.nix.
#
# Fields (all optional except `desktop`):
#   desktop        "hyprland" | "xfce" | "gnome"
#   username       default: "lakin"
#   hardware       list of nixos-hardware module name strings, default: []
#   hyprlandChannel
#                  Which Hyprland pin set to build against: "stable" (default)
#                  or "next". The channel moves Hyprland, its portal, and the
#                  plugin pins together, which is why it is one field rather
#                  than a version plus separate plugin toggles.
#                    stable — Hyprland v0.55.4; hyprexpo, hypr-dynamic-cursors
#                             and hyprgrass all available.
#                    next   — Hyprland v0.56.0 + xdg-desktop-portal-hyprland
#                             v1.4.0, which supplies the input-capture portal
#                             (libei) that lan-mouse uses in place of its
#                             layer-shell capture. hyprexpo and
#                             hypr-dynamic-cursors are pinned to matching 0.56
#                             builds. No hyprgrass pin — "next" with
#                             hyprgrass = true throws.
#   hyprgrass      enable touch gestures (Surface), default: false
#   hyprHostConfig hyprland monitor/input config string, default: ""
#   hyprWallpaper  path to wallpaper, default: ./hypr/wallpaper.jpg
#   hyprDynamicCursorsMode
#                  hypr-dynamic-cursors simulation mode (shake-to-find is
#                  always on). One of "none" | "tilt" | "rotate" | "stretch"
#                  (stretch = comic squash/stretch). Default: "none".
#   hyprIdleTimeouts
#                  hypridle listener timeouts in seconds. Keys dim / lock /
#                  dpms / suspend, each overridable on its own; defaults are
#                  181 / 300 / 600 / 900. suspend = 0 drops the suspend
#                  listener entirely. Default: {} (all four defaults).
#   hyprLockGrace  seconds hyprlock stays dismissible by any input before it
#                  demands a password. Default: 2. Raise on machines that only
#                  lock somewhere private.
#   hyprSuspendOnAc
#                  idle-suspend while on mains power, default: true. false
#                  makes the suspend listener skip when any power supply
#                  reports online, so the host still idle-suspends on battery.
#                  Dim/lock/dpms and logind's lid-close suspend are unaffected.
#   xfceWallpaper  path to wallpaper, default: null
#   xfceAvatar     path to avatar, default: null
#   ghosttyOpacity ghostty background-opacity, 0.0-1.0, default: 0.85
#   ollamaCuda     enable CUDA ollama, default: false
#   devTools       install the heavier dev modules (nvim/LazyVim, zellij,
#                  ollama, latex). Default: true. Set false for a trimmed
#                  machine. Note: CLI tools (git TUIs, k8s, DBs, btop, …)
#                  live in ../cli-tools and are installed everywhere.
#   diskoConfig    path to disko-config.nix, default: ./disko-config.nix
#   extraModules   list of extra NixOS modules, default: []
{
  harry = {
    # Surface Pro 9 (Intel)
    desktop = "hyprland";
    hardware = [ "microsoft-surface-pro-intel" ];
    hyprgrass = true;
    hyprHostConfig = ''
      -- Swap Alt and Super to match Mac-style layout
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
        # In /etc rather than ~/.config, matching trunkie — see the note there.
        environment.etc."lan-mouse/config.toml".text = ''
          port = 4343

          # trunkie's certificate fingerprint. Without it the DTLS handshake is
          # rejected with "Alert is Fatal or Close Notify".
          [authorized_fingerprints]
          "44:bc:eb:83:d7:a3:e8:99:1c:57:e8:7b:4e:01:67:7a:f4:45:c2:64:9e:5a:e5:79:5b:ae:ba:23:58:fe:b7:6a" = "trunkie"

          # trunkie — above harry. Peers are [[clients]] entries with a
          # `position` key as of lan-mouse 0.11; the old [top]/[left] section
          # form is silently ignored.
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
    hyprlandChannel = "next";
    hyprDynamicCursorsMode = "tilt";
    # Don't idle-suspend when on AC power. Battery still suspends; lid-close
    # still suspends via logind. hypridle still dims/locks/dpms (screen off).
    hyprSuspendOnAc = false;
    hyprHostConfig = ''
      -- AMD laptop — 2560x1600@120Hz display, 1.25x scale
      hl.monitor({ output = "eDP-1", mode = "2560x1600@120", position = "auto", scale = 1.25 })
      hl.monitor({ output = "",      mode = "preferred",     position = "auto", scale = 1 })

      -- Swap Alt and Super to match Mac-style layout (laptop keyboard only)
      hl.device({
          name = "at-translated-set-2-keyboard",
          kb_options = "altwin:swap_lalt_lwin,caps:backspace",
      })
    '';
  };

  trunkie = {
    # Threadripper 1950X desktop — AMD GPU, 64GB RAM
    # 3 disks: unmirrored root (931G) + home btrfs RAID1 (1.9T + 1.8T)
    desktop = "hyprland";
    hardware = [ "common-cpu-amd" "common-gpu-amd" "common-pc" "common-pc-ssd" ];
    diskoConfig = ./hosts/trunkie/disko-config.nix;
    hyprWallpaper = ./hypr/wallpaper-trunkie.jpg;
    # Fully opaque: the Calgary wallpaper is bright, so any bleed-through
    # washes out light-theme terminal text.
    ghosttyOpacity = 1.0;
    # lan-mouse needs the InputCapture portal, which only exists in
    # xdg-desktop-portal-hyprland >= 1.4.0. Costs hyprexpo (no v0.56.2 build),
    # which is a touchpad gesture this desktop can't use anyway.
    hyprlandChannel = "latest";
    # Never idle-suspend; the sleep targets are masked in hosts/trunkie.
    # dpms 10s after the lock instead of the default 600 — once it locks there
    # is no reason to keep two big panels lit. That lands exactly as the 10s
    # hyprLockGrace expires, so the screens go dark when the lock goes hard.
    hyprIdleTimeouts = { suspend = 0; dpms = 310; };
    hyprLockGrace = 10;
    # HDMI-A-1 is shared with a KVM, so it disappears whenever the switch hands
    # it to the other machine. Its mode is bound to a name here because the
    # re-enable keybind has to repeat the mode string verbatim — keeping the two
    # in sync by hand is how they drift.
    # One spec shared by the initial hl.monitor call and the F10 re-enable, so
    # the two cannot drift — the reason the old config bound the mode string to
    # a name as well.
    hyprHostConfig = ''
      -- 4K landscape panel (KVM-shared) — 1.25x scale, 3072x1728 logical at 0x0
      hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@120", position = "0x0", scale = 1.25 })
      -- 1440p panel rotated 270deg, standing to the right of the 4K
      hl.monitor({ output = "DP-1", mode = "2560x1440@164", position = "3072x-420", scale = 1, transform = 3 })

      hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })

      -- KVM switch: F9 drops the shared 4K when it hands over to the other
      -- machine, F10 brings it back. Disabling it explicitly is what makes
      -- Hyprland reflow the windows instead of stranding them on a panel that
      -- is no longer displaying this host.
      --
      -- Routed through kvm-monitor.sh because dropping the panel also has to
      -- restart lan-mouse: the portal refuses a pointer barrier on the shared
      -- HDMI-A-1/DP-1 edge while both are present (interior boundary), and
      -- lan-mouse only asks for barriers when its capture session starts. See
      -- the script for the full reasoning.
      --
      -- The script uses `hyprctl eval` / `hyprctl reload`; `hyprctl keyword` is
      -- hyprlang-only and under a Lua config silently does nothing.
      hl.bind("CTRL + SUPER + SHIFT + F9",  hl.dsp.exec_cmd("/etc/hypr/scripts/kvm-monitor.sh off HDMI-A-1"))
      hl.bind("CTRL + SUPER + SHIFT + F10", hl.dsp.exec_cmd("/etc/hypr/scripts/kvm-monitor.sh on HDMI-A-1"))

      -- Send the current workspace to a named panel. By name, not monitor ID,
      -- because the KVM hotplug above renumbers the IDs.
      hl.bind("SUPER + ALT + 1", hl.dsp.workspace.move({ monitor = "HDMI-A-1" }))
      hl.bind("SUPER + ALT + 2", hl.dsp.workspace.move({ monitor = "DP-1" }))
    '';
    extraModules = [
      ({ ... }: {
        # lan-mouse server — trunkie owns the physical keyboard and mouse.
        # In /etc, not ~/.config: activation runs from the initrd here (see
        # boot.initrd.systemd.enable), before /home is mounted, so a home-
        # written config is shadowed the moment /home mounts over it.
        # `position` is the peer's location relative to this host, so the Mac
        # sitting to the left of the desk is position = "left".
        environment.etc."lan-mouse/config.toml".text = ''
          port = 4343

          # 0.11 encrypts with DTLS: a peer whose certificate fingerprint is
          # not listed here is rejected at handshake with
          # "Alert is Fatal or Close Notify". Fingerprints belong here rather
          # than only in `lan-mouse cli authorize-key`, which writes runtime
          # state this file overwrites on every rebuild.
          [authorized_fingerprints]
          "8b:73:b1:29:df:1d:50:bb:92:ce:d1:15:21:ae:af:45:b8:a0:21:14:33:d1:ee:8e:14:50:0a:d9:ac:15:6f:6b" = "phoebe"

          # phoebe (Mac) — left of trunkie.
          # ips is required: lan-mouse's resolver has no mDNS, so
          # "phoebe.local" alone never resolves (feschber/lan-mouse#234).
          [[clients]]
          position = "left"
          hostname = "phoebe.local"
          ips = ["192.168.50.52"]
          port = 4343
          activate_on_startup = true
        '';
      })
    ];
  };

  roach = {
    # Asus TUF F16 (Intel + NVIDIA)
    desktop = "hyprland";
    hardware = [ "common-cpu-intel" "common-gpu-nvidia-nonprime" "common-pc-laptop" "common-pc-laptop-ssd" ];
    diskoConfig = ./hosts/roach/disko-config.nix;
    ollamaCuda = true;
    hyprIdleTimeouts = { dim = 360; lock = 600; dpms = 1200; };
    # Don't idle-suspend when on AC power (lid open). Battery still suspends;
    # lid-close still suspends via logind. hypridle still dims/locks/dpms.
    hyprSuspendOnAc = false;
    hyprHostConfig = ''
      -- Asus TUF F16 — 2560x1600 display, 1.25x scale
      hl.monitor({ output = "eDP-1",     mode = "preferred",    position = "1920x0", scale = 1.25 })
      hl.monitor({ output = "HDMI-A-2",  mode = "1920x1080@60", position = "0x0",    scale = 1 })
      hl.monitor({ output = "",          mode = "preferred",    position = "auto",   scale = 1 })

      -- Swap Alt and Super to match Mac-style layout (laptop keyboard only)
      hl.device({
          name = "at-translated-set-2-keyboard",
          kb_options = "altwin:swap_lalt_lwin,caps:backspace",
      })
    '';
    hyprWallpaper = ./hypr/wallpaper-roach.jpg;
  };

  shrike = {
    # Dell XPS 16 9650 (2026, Intel Panther Lake — Core Ultra X9 388H, Arc iGPU)
    # Temporary install to test before going back to Ubuntu.
    desktop = "hyprland";
    hardware = [ "common-cpu-intel" "common-pc-laptop" "common-pc-laptop-ssd" ];
    hyprHostConfig = ''
      -- Dell XPS 16 — 16" OLED 2880x1800 touch, 1.5x scale
      hl.monitor({ output = "eDP-1", mode = "2880x1800@60", position = "auto", scale = 1.5 })
      hl.monitor({ output = "",      mode = "preferred",    position = "auto", scale = 1 })

      -- Swap Alt and Super to match Mac-style layout (laptop keyboard only)
      hl.device({
          name = "at-translated-set-2-keyboard",
          kb_options = "altwin:swap_lalt_lwin",
      })

      -- Enable tap-to-click — haptic pad has no physical click button
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
    # Dell XPS 13 9370 (2018, 8th-gen Kaby Lake R, rose gold) — Anita's laptop
    desktop = "gnome";
    username = "anita";
    hardware = [ "dell-xps-13-9370" ];
    devTools = false;   # normal-user machine, skip the dev kitchen sink
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
