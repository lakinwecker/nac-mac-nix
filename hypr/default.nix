# Force rebuild
{ pkgs, lib, username, hyprland, hyprgrass ? null, hyprDynamicCursors, hyprexpo-src, hyprHostConfig ? "", hyprWallpaper ? ./wallpaper.jpg, hyprDynamicCursorsMode ? "none", hyprIdleTimeouts ? {}, hyprSuspendOnAc ? true, ... }:
let
  hyprgrassEnabled = hyprgrass != null;
  idle = {
    dim       = hyprIdleTimeouts.dim or 181;
    lock      = hyprIdleTimeouts.lock or 300;
    dpms      = hyprIdleTimeouts.dpms or 600;
    suspend   = hyprIdleTimeouts.suspend or 900;
  };
  hypridleConf = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
        timeout = ${toString idle.dim}
        on-timeout = sh -c 'brightnessctl get > /tmp/.brightness-before-dim && brightnessctl set 10%'
        on-resume = sh -c 'test -f /tmp/.brightness-before-dim && brightnessctl set $(cat /tmp/.brightness-before-dim) || brightnessctl set 100%'
    }

    listener {
        timeout = ${toString idle.lock}
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = ${toString idle.dpms}
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }
  '' + lib.optionalString (idle.suspend > 0) ''

    listener {
        timeout = ${toString idle.suspend}
        on-timeout = ${suspendCmd}
    }
  '';
  # When hyprSuspendOnAc is false, only idle-suspend on battery: skip the
  # suspend if any mains adapter reports online (i.e. AC is plugged in).
  # Lid-close suspend is handled by logind and is unaffected by this.
  suspendCmd =
    if hyprSuspendOnAc
    then "systemctl suspend"
    else "sh -c 'grep -lq 1 /sys/class/power_supply/*/online 2>/dev/null || systemctl suspend'";
  # Shake-to-find is on by default for every Hyprland host. `mode` (tilt /
  # rotate / stretch / none) is opt-in per-host via machines.nix.
  hyprexpo = pkgs.callPackage hyprexpo-src {
    inherit (hyprland.packages.${pkgs.system}) hyprland;
    inherit (pkgs) hyprlandPlugins;
  };
  hyprexpoConfig = ''
    plugin = /etc/hypr/plugins/hyprexpo.so

    plugin:hyprexpo {
        columns = 3
        gap_size = 15
        bg_col = rgb(111111)
        workspace_method = first 1
        gesture_distance = 300
    }
  '';
  dynamicCursorsConfig = ''
    plugin = /etc/hypr/plugins/hypr-dynamic-cursors.so

    plugin:dynamic-cursors {
        enabled = true
        mode = ${hyprDynamicCursorsMode}

        shake {
            enabled = true
            # Lower than the 6.0 default — triggers magnification sooner.
            threshold = 4.0
        }
    }
  '';
in {
  imports = [ hyprland.nixosModules.default ];

  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "hyprland" "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };

  environment.etc."hypr/plugins/hyprgrass.so" = lib.mkIf hyprgrassEnabled {
    source = "${(hyprgrass.packages.${pkgs.system}.default.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [ pkgs.lua ];
    }))}/lib/libhyprgrass.so";
  };

  environment.etc."hypr/plugins/hypr-dynamic-cursors.so".source =
    "${hyprDynamicCursors.packages.${pkgs.system}.default}/lib/libhypr-dynamic-cursors.so";

  environment.etc."hypr/plugins/hyprexpo.so".source =
    "${hyprexpo}/lib/libhyprexpo.so";

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${hyprland.packages.${pkgs.system}.hyprland}/bin/start-hyprland";
        user = username;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    rofi
    nwg-drawer
    bibata-cursors          # XCURSOR fallback for xwayland / X11 apps
    rose-pine-hyprcursor    # SVG-based hyprcursor — sharp at magnification
    hyprlock
    hypridle
    hyprpolkitagent
    hyprpanel
    playerctl
    brightnessctl
    wl-clipboard
    wtype
    grim
    slurp
    wf-recorder
    python3
    socat
    wvkbd
    iio-hyprland
    # Must-have utilities
    xdg-desktop-portal-gtk
    qt5.qtwayland
    kdePackages.qtwayland
    # HyprPanel recommended deps
    libgtop
    dart-sass
    gvfs
    gtksourceview3
    libsoup_3
    # HyprPanel optional deps
    hyprsunset
    pywal
    awww
    matugen
    grimblast
    hyprpicker
    bluez
    bluez-tools
    overskride
    pavucontrol
    power-profiles-daemon
  ];

  environment.etc."hypr/scripts/mac-shortcut.sh" = {
    source = ./scripts/mac-shortcut.sh;
    mode = "0755";
  };

  environment.etc."hypr/scripts/battery-borders.sh" = {
    source = ./scripts/battery-borders.sh;
    mode = "0755";
  };

  environment.etc."hypr/scripts/screenshot-delayed.sh" = {
    source = ./scripts/screenshot-delayed.sh;
    mode = "0755";
  };

  environment.etc."hypr/rofi-tokyonight.rasi".source = ./rofi-tokyonight.rasi;
  environment.etc."hypr/nwg-drawer.css".source = ./nwg-drawer.css;

  environment.etc."hypr/hyprland.conf".text =
    builtins.readFile ./hyprland.conf
    + lib.optionalString hyprgrassEnabled (builtins.readFile ./hyprgrass.conf)
    + "\n# hyprexpo plugin\n" + hyprexpoConfig
    + "\n# hypr-dynamic-cursors plugin\n" + dynamicCursorsConfig
    + "\n# Per-host overrides\n" + hyprHostConfig;
  environment.etc."hypr/hypridle.conf".text = hypridleConf;
  environment.etc."hypr/hyprlock.conf".source = ./hyprlock.conf;
  environment.etc."wallpaper.jpg".source = hyprWallpaper;
  environment.etc."hyprpanel/config-dark.json".source = ./hyprpanel-config.json;
  environment.etc."hyprpanel/config-light.json".source = ./hyprpanel-config-light.json;
  environment.etc."btop/btop.conf".source = ./btop.conf;
  environment.etc."avatar.png".source = ./avatar.png;

  system.activationScripts.hyprConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${username} -g users /home/${username}/.config
      install -d -o ${username} -g users /home/${username}/.config/hypr
      install -d -o ${username} -g users /home/${username}/.config/hyprpanel
      install -d -o ${username} -g users /home/${username}/.config/hyprpanel/styles
      install -d -o ${username} -g users /home/${username}/.config/btop
      ln -sf /etc/btop/btop.conf /home/${username}/.config/btop/btop.conf
      chown -h ${username}:users /home/${username}/.config/btop/btop.conf
      ln -sf /etc/hypr/hyprland.conf /home/${username}/.config/hypr/hyprland.conf
      ln -sf /etc/hypr/hypridle.conf /home/${username}/.config/hypr/hypridle.conf
      ln -sf /etc/hypr/hyprlock.conf /home/${username}/.config/hypr/hyprlock.conf
      chown -h ${username}:users /home/${username}/.config/hypr/hyprland.conf /home/${username}/.config/hypr/hypridle.conf /home/${username}/.config/hypr/hyprlock.conf
      # Pick the hyprpanel variant matching the current theme mode (set by
      # theme-toggle). Defaults to dark if state file is absent.
      mode="dark"
      if [ -r /home/${username}/.local/state/theme-mode ]; then
        mode=$(cat /home/${username}/.local/state/theme-mode)
      fi
      install -m 0644 -o ${username} -g users \
        /etc/hyprpanel/config-$mode.json \
        /home/${username}/.config/hyprpanel/config.json
      install -m 0644 -o ${username} -g users /etc/avatar.png /home/${username}/.face.icon
      install -m 0644 -o ${username} -g users /etc/wallpaper.jpg /home/${username}/.config/background
    '';
  };
}
