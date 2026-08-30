# Force rebuild
{ pkgs, lib, username, hyprland, hyprgrass ? null, hyprDynamicCursors, hyprexpoSrc, hyprHostConfig ? "", hyprWallpaper ? ./wallpaper.jpg, hyprDynamicCursorsMode ? "none", hyprIdleTimeouts ? {}, hyprSuspendOnAc ? true, hyprLockGrace ? 2, ... }:
let
  hyprgrassEnabled = hyprgrass != null;
  hyprexpoEnabled = hyprexpoSrc != null;
  # Wayle bar config: one shared base (layout + modules + osd + wallpaper)
  # concatenated with a per-mode [styling.palette] block to produce the two
  # theme variants. theme-toggle swaps the whole file + `wayle panel restart`.
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
  hypridleConf = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = sh -c 'hyprctl dispatch dpms on; wayle panel show'
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
        on-timeout = sh -c 'wayle panel hide; hyprctl dispatch dpms off'
        on-resume = sh -c 'hyprctl dispatch dpms on; wayle panel show'
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
                gap_size = 15,
                bg_col = "rgb(111111)",
                workspace_method = "first 1",
                gesture_distance = 300,
            },
        },
    })

    -- hyprexpo overview. Routed via exec because the direct dispatcher /
    -- hyprexpo-gesture don't fire from a swipe on some touchpads (roach),
    -- though they work from the CLI.
    -- action takes a string action name, a table of start/update/finish
    -- callbacks, or a plain Lua function. A bare dispatcher falls through to
    -- the string parser and errors, so wrap it in a function.
    hl.gesture({
        fingers = 3,
        direction = "up",
        action = function()
            hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch hyprexpo:expo toggle"))
        end,
    })
  '';
  # dynamic_cursors, not "dynamic-cursors": CConfigManager::luaConfigValueName
  # rewrites ':' to '.' AND '-' to '_', so the Lua name for
  # plugin:dynamic-cursors:shake:threshold is
  # plugin.dynamic_cursors.shake.threshold. `hyprctl getoption` still reports
  # the legacy colon/hyphen form, which is what makes this easy to get wrong.
  #
  # Note the plugin loads *after* the first config pass, so its keys are
  # unknown then; handlePluginLoads() calls reload() once plugins are in, and
  # the values apply on that second pass.
  dynamicCursorsConfig = ''
    hl.plugin.load("/etc/hypr/plugins/hypr-dynamic-cursors.so")

    hl.config({
        plugin = {
            dynamic_cursors = {
                enabled = true,
                mode = "${hyprDynamicCursorsMode}",

                shake = {
                    enabled = true,
                    -- Lower than the 6.0 default — magnifies sooner.
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
    source = ./scripts/power-menu.sh;
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

  # Power key opens the rofi menu via hyprland.lua; a long press still poweroffs.
  services.logind.settings.Login = {
    HandlePowerKey = lib.mkDefault "ignore";
    HandlePowerKeyLongPress = lib.mkDefault "poweroff";
  };

  environment.etc."hypr/rofi-tokyonight.rasi".source = ./rofi-tokyonight.rasi;
  environment.etc."hypr/nwg-drawer.css".source = ./nwg-drawer.css;

  # hyprland.lua, not hyprland.conf: hyprlang was deprecated in 0.55 and is
  # dropped in 0.57. hyprlock/hypridle still take hyprlang and are unaffected.
  environment.etc."hypr/hyprland.lua".text =
    builtins.readFile ./hyprland.lua
    + lib.optionalString hyprgrassEnabled ("\n-- hyprgrass plugin\n" + builtins.readFile ./hyprgrass.lua)
    + lib.optionalString hyprexpoEnabled ("\n-- hyprexpo plugin\n" + hyprexpoConfig)
    + "\n-- hypr-dynamic-cursors plugin\n" + dynamicCursorsConfig
    + "\n-- Per-host overrides\n" + hyprHostConfig;
  environment.etc."hypr/hypridle.conf".text = hypridleConf;
  # grace = seconds the lockscreen stays dismissible by any input before it
  # actually demands a password. Appended rather than baked into the file so
  # hosts can differ: a desk machine can afford 10s, a laptop that locks in
  # public should not.
  # Started from hyprland.lua's autostart hook. Exists only so graphical-session
  # .target can be reached: that target refuses manual start, but BindsTo pulls
  # it in as a dependency, which is what lets user services bound to it run.
  systemd.user.targets.hyprland-session = {
    description = "Hyprland session";
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  environment.etc."hypr/hyprlock.conf".text =
    builtins.replaceStrings [ "@GRACE@" ] [ (toString hyprLockGrace) ]
      (builtins.readFile ./hyprlock.conf);

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
      # Pick the wayle variant matching the current theme mode (set by
      # theme-toggle). Defaults to dark if state file is absent.
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
