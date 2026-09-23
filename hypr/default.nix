{ pkgs, lib, username, hyprland, hyprgrass ? null, hyprDynamicCursors, hyprexpoSrc, hyprHostConfig ? "", hyprWallpaper ? ./wallpaper.jpg, hyprDynamicCursorsMode ? "none", hyprIdleTimeouts ? {}, hyprSuspendOnAc ? true, hyprLockGrace ? 2, hyprHibernate ? true, ... }:
let
  hyprgrassEnabled = hyprgrass != null;
  hyprexpoEnabled = hyprexpoSrc != null;
  # No state file (every host but roach) means hybrid — env left untouched.
  startSession = pkgs.writeShellScript "start-hyprland-session" ''
    if [ "$(cat /var/lib/gpu-mode/mode 2>/dev/null || echo hybrid)" = mux ]; then
      export AQ_DRM_DEVICES=/dev/dri/dgpu
      export GBM_BACKEND=nvidia-drm
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __NV_PRIME_RENDER_OFFLOAD=0
    fi
    exec ${hyprland.packages.${pkgs.system}.hyprland}/bin/start-hyprland
  '';
  # base.toml + a per-mode palette block; theme-toggle swaps the whole file.
  mkWayleConfig = name: palette:
    pkgs.runCommand name { } ''
      cat ${./wayle/base.toml} ${palette} > $out
    '';
  wayleDark  = mkWayleConfig "wayle-config-dark.toml"  ./wayle/palette-dark.toml;
  wayleLight = mkWayleConfig "wayle-config-light.toml" ./wayle/palette-light.toml;
  idle = {
    dim       = hyprIdleTimeouts.dim or 181;
    lock      = hyprIdleTimeouts.lock or 300;
    dpms      = hyprIdleTimeouts.dpms or 600;
    suspend   = hyprIdleTimeouts.suspend or 900;
  };
  # `grace` is a CLI flag in hyprlock 0.9.x; `general:grace` in hyprlock.conf
  # is rejected outright.
  lockCmd = "pidof hyprlock || hyprlock --grace ${toString hyprLockGrace}";
  hypridleConf = ''
    general {
        lock_cmd = ${lockCmd}
        before_sleep_cmd = ${lockCmd}
        after_sleep_cmd = /etc/hypr/scripts/idle-dpms.sh on
    }

    listener {
        timeout = ${toString idle.dim}
        on-timeout = sh -c 'brightnessctl get > /tmp/.brightness-before-dim && brightnessctl set 10%'
        on-resume = sh -c 'test -f /tmp/.brightness-before-dim && brightnessctl set $(cat /tmp/.brightness-before-dim) || brightnessctl set 100%'
    }

    listener {
        timeout = ${toString idle.lock}
        # Not `loginctl lock-session`: logind classes this greetd session as a
        # greeter and refuses Lock(), silently dropping the listener.
        on-timeout = ${lockCmd}
    }

    listener {
        timeout = ${toString idle.dpms}
        on-timeout = /etc/hypr/scripts/idle-dpms.sh off
        on-resume = /etc/hypr/scripts/idle-dpms.sh on
    }
  '' + lib.optionalString (idle.suspend > 0) ''

    listener {
        timeout = ${toString idle.suspend}
        on-timeout = ${suspendCmd}
    }
  '';
  # Lid-close suspend is logind's and is unaffected by this.
  suspendCmd =
    if hyprSuspendOnAc
    then "systemctl suspend"
    else "sh -c 'grep -lq 1 /sys/class/power_supply/*/online 2>/dev/null || systemctl suspend'";
  hyprlandPackage = hyprland.packages.${pkgs.system}.hyprland;
  hyprexpo = pkgs.callPackage hyprexpoSrc {
    hyprland = hyprlandPackage;
    hyprlandPlugins = pkgs.hyprlandPlugins.override { hyprland = hyprlandPackage; };
  };
  hyprexpoConfig = ''
    hl.plugin.load("/etc/hypr/plugins/hyprexpo.so")

    hl.config({
        plugin = {
            hyprexpo = {
                columns = 4,
                -- The sandwichfarm fork splits upstream's `gap_size` into
                -- gaps_in/gaps_out; `gap_size` is an unknown key here.
                gaps_in = 15,
                gaps_out = 0,
                bg_col = "rgb(111111)",
                workspace_method = "first 1",
                gesture_distance = 300,
            },
        },
    })

    -- hl.plugin.hyprexpo.expo acts directly; it is not a dispatcher, so no
    -- hl.dispatch wrapper. Unguarded is safe: these closures run after load.
    hl.gesture({
        fingers = 3,
        direction = "up",
        action = function()
            hl.plugin.hyprexpo.expo("toggle")
        end,
    })

    hl.bind("SUPER + Up", function()
        hl.plugin.hyprexpo.expo("toggle")
    end, { description = "Toggle hyprexpo overview" })
  '';
  # dynamic_cursors, not "dynamic-cursors": Lua config keys rewrite ':' to '.'
  # and '-' to '_', though `hyprctl getoption` still reports the legacy form.
  dynamicCursorsConfig = ''
    hl.plugin.load("/etc/hypr/plugins/hypr-dynamic-cursors.so")

    hl.config({
        plugin = {
            dynamic_cursors = {
                enabled = true,
                mode = "${hyprDynamicCursorsMode}",

                shake = {
                    enabled = true,
                    -- Default is 6.0; lower magnifies sooner.
                    threshold = 4.0,
                },
            },
        },
    })
  '';
in {
  imports = [ hyprland.nixosModules.default ];

  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  programs.steam.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "hyprland" "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
      hyprland."org.freedesktop.impl.portal.InputCapture" = [ "hyprland" ];
    };
  };

  environment.etc."hypr/plugins/hyprgrass.so" = lib.mkIf hyprgrassEnabled {
    source = "${(hyprgrass.packages.${pkgs.system}.default.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [ pkgs.lua ];
    }))}/lib/libhyprgrass.so";
  };

  environment.etc."hypr/plugins/hypr-dynamic-cursors.so".source =
    "${hyprDynamicCursors.packages.${pkgs.system}.default}/lib/libhypr-dynamic-cursors.so";

  environment.etc."hypr/plugins/hyprexpo.so" = lib.mkIf hyprexpoEnabled {
    source = "${hyprexpo}/lib/libhyprexpo.so";
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${startSession}";
        user = username;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    rofi
    wlogout                 # power menu — GTK3, so it takes touch (rofi does not)
    nwg-drawer
    bibata-cursors          # XCURSOR fallback for xwayland / X11 apps
    rose-pine-hyprcursor    # SVG-based hyprcursor — sharp at magnification
    hyprlock
    hypridle
    hyprpolkitagent
    wayle
    playerctl
    brightnessctl
    wl-clipboard
    wtype
    grim
    slurp
    imagemagick   # rounded-corner alpha mask for screenshots
    libwebp       # cwebp
    wf-recorder
    wl-screenrec  # VAAPI-encoded capture; keeps recording off the CPU
    python3
    socat
    wvkbd
    iio-hyprland
    # Must-have utilities
    xdg-desktop-portal-gtk
    qt5.qtwayland
    kdePackages.qtwayland
    # General desktop utilities
    gvfs
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

  environment.etc."hypr/scripts/screenshot.sh" = {
    source = ./scripts/screenshot.sh;
    mode = "0755";
  };

  environment.etc."hypr/scripts/power-menu.sh" = {
    source = pkgs.runCommand "power-menu.sh" { } ''
      cp ${./scripts/power-menu.sh} $out
      substituteInPlace $out \
        --replace-fail '@hibernate@' '${if hyprHibernate then "1" else "0"}'
    '';
    mode = "0755";
  };

  environment.etc."hypr/scripts/kvm-monitor.sh" = {
    source = ./scripts/kvm-monitor.sh;
    mode = "0755";
  };

  environment.etc."hypr/scripts/lan-mouse-toggle.sh" = {
    source = ./scripts/lan-mouse-toggle.sh;
    mode = "0755";
  };

  environment.etc."hypr/scripts/idle-dpms.sh" = {
    source = ./scripts/idle-dpms.sh;
    mode = "0755";
  };

  environment.etc."hypr/scripts/hypr-lua.sh" = {
    source = ./scripts/hypr-lua.sh;
    mode = "0644";
  };

  # Power key opens the wlogout menu via hyprland.lua; a long press still poweroffs.
  services.logind.settings.Login = {
    HandlePowerKey = lib.mkDefault "ignore";
    HandlePowerKeyLongPress = lib.mkDefault "poweroff";
  };

  # Stamp /run/last-resume so power-menu.sh can tell a wake press from a
  # request for the menu. mkBefore: host modules add slow work to this merged
  # `lines`, and a late stamp would burn most of the grace window.
  powerManagement.resumeCommands = lib.mkBefore ''
    ${pkgs.coreutils}/bin/touch /run/last-resume
  '';

  environment.etc."hypr/rofi-tokyonight.rasi".source = ./rofi-tokyonight.rasi;

  # GTK CSS needs absolute icon paths, so substitute the store path at build.
  environment.etc."hypr/wlogout.css".source =
    pkgs.runCommand "wlogout.css" { } ''
      cp ${./wlogout.css} $out
      substituteInPlace $out \
        --replace-fail '@icons@' '${pkgs.wlogout}/share/wlogout/icons'
    '';
  environment.etc."hypr/nwg-drawer.css".source = ./nwg-drawer.css;

  # hyprland.lua, not hyprland.conf: hyprlang is dropped in 0.57. hyprlock and
  # hypridle still take hyprlang.
  environment.etc."hypr/hyprland.lua".text =
    builtins.readFile ./hyprland.lua
    + lib.optionalString hyprgrassEnabled ("\n-- hyprgrass plugin\n" + builtins.readFile ./hyprgrass.lua)
    + lib.optionalString hyprexpoEnabled ("\n-- hyprexpo plugin\n" + hyprexpoConfig)
    + "\n-- hypr-dynamic-cursors plugin\n" + dynamicCursorsConfig
    + "\n-- Per-host overrides\n" + hyprHostConfig;
  environment.etc."hypr/hypridle.conf".text = hypridleConf;
  # Started from hyprland.lua's autostart hook. Exists only to reach
  # graphical-session.target, which refuses manual start but can be BindsTo'd.
  systemd.user.targets.hyprland-session = {
    description = "Hyprland session";
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  environment.etc."hypr/hyprlock.conf".source = ./hyprlock.conf;

  # hyprlock does pam_start("hyprlock"); without this it has no auth backend.
  security.pam.services.hyprlock = { };
  environment.etc."wallpaper.jpg".source = hyprWallpaper;
  environment.etc."wayle/config-dark.toml".source = wayleDark;
  environment.etc."wayle/config-light.toml".source = wayleLight;
  environment.etc."btop/btop.conf".source = ./btop.conf;
  environment.etc."avatar.png".source = ./avatar.png;

  system.activationScripts.hyprConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${username} -g users /home/${username}/.config
      install -d -o ${username} -g users /home/${username}/.config/hypr
      install -d -o ${username} -g users /home/${username}/.config/wayle
      install -d -o ${username} -g users /home/${username}/.config/btop
      ln -sf /etc/btop/btop.conf /home/${username}/.config/btop/btop.conf
      chown -h ${username}:users /home/${username}/.config/btop/btop.conf
      ln -sf /etc/hypr/hyprland.lua /home/${username}/.config/hypr/hyprland.lua
      ln -sf /etc/hypr/hypridle.conf /home/${username}/.config/hypr/hypridle.conf
      ln -sf /etc/hypr/hyprlock.conf /home/${username}/.config/hypr/hyprlock.conf
      chown -h ${username}:users /home/${username}/.config/hypr/hyprland.lua /home/${username}/.config/hypr/hypridle.conf /home/${username}/.config/hypr/hyprlock.conf
      mode="dark"
      if [ -r /home/${username}/.local/state/theme-mode ]; then
        mode=$(cat /home/${username}/.local/state/theme-mode)
      fi
      install -m 0644 -o ${username} -g users \
        /etc/wayle/config-$mode.toml \
        /home/${username}/.config/wayle/config.toml
      install -m 0644 -o ${username} -g users /etc/avatar.png /home/${username}/.face.icon
      install -m 0644 -o ${username} -g users /etc/wallpaper.jpg /home/${username}/.config/background
    '';
  };
}
