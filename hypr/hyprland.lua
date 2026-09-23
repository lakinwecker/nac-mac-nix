-- Shared across all hosts. hypr/default.nix appends the plugin blocks and the
-- per-host hyprHostConfig from machines.nix to this file.

hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2, transform = 0 })
hl.monitor({ output = "",      mode = "preferred", position = "auto", scale = 2 })

hl.config({
    input = {
        repeat_rate  = 100,
        repeat_delay = 250,

        follow_mouse = 2,

        touchpad = {
            natural_scroll = true,
            tap_to_click   = false,
        },

        touchdevice = {
            enabled = true,
        },
    },

    gestures = {
        workspace_swipe_cancel_ratio       = 0.3,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_create_new         = true,
    },

    dwindle = {
        special_scale_factor = 0.91,
    },

    general = {
        gaps_in     = 4,
        gaps_out    = 4,
        border_size = 2,
        col = {
            active_border   = "0xffd7827e",
            inactive_border = "0xff286983",
        },
    },

    decoration = {
        rounding         = 8,
        inactive_opacity = 1.0,
        active_opacity   = 1.0,
    },

    animations = {
        enabled = true,
    },

    misc = {
        disable_hyprland_logo = true,

        -- Default false, which leaves the screens unwakeable by input once
        -- hypridle blanks them; the only way back would be hypridle itself.
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })
hl.gesture({ fingers = 4, direction = "vertical",   action = "resize" })
hl.gesture({ fingers = 3, direction = "down",       action = "fullscreen" })

-- rose-pine ships hyprcursor only; Bibata is the XCURSOR fallback for X11.
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "32")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "32")

hl.on("hyprland.start", function()
    -- greetd never pulls in graphical-session.target, and that target refuses
    -- manual start; hyprland-session.target (hypr/default.nix) BindsTo it.
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    hl.exec_cmd("iio-hyprland eDP-1")
    hl.exec_cmd("hyprctl setcursor rose-pine-hyprcursor 32")
    hl.exec_cmd("hypridle")

    -- Two calls, not `&&`: awww-daemon runs in the foreground and never exits.
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 1 && awww img /etc/wallpaper.jpg")

    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("wayle shell")
    hl.exec_cmd("/etc/hypr/scripts/battery-borders.sh")
end)

hl.workspace_rule({ workspace = "11", persistent = true })
hl.workspace_rule({ workspace = "12", persistent = true })
hl.workspace_rule({ workspace = "13", persistent = true })
hl.workspace_rule({ workspace = "14", persistent = true })

-- Mac-style copy/paste via X11 legacy keys, which work in terminals and GUI.
hl.bind("SUPER + C", hl.dsp.send_shortcut({ mods = "CTRL",  key = "Insert" }), { description = "Universal copy" })
hl.bind("SUPER + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }), { description = "Universal paste" })
hl.bind("SUPER + X", hl.dsp.exec_cmd("/etc/hypr/scripts/mac-shortcut.sh cut"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("/etc/hypr/scripts/mac-shortcut.sh select-all"))
hl.bind("SUPER + Z", hl.dsp.exec_cmd("/etc/hypr/scripts/mac-shortcut.sh undo"))
hl.bind("SUPER + SHIFT + Z", hl.dsp.exec_cmd("/etc/hypr/scripts/mac-shortcut.sh redo"))

hl.bind("CTRL + SUPER + SHIFT + T", hl.dsp.exec_cmd("theme-toggle"))

hl.bind("CTRL + SUPER + M", hl.dsp.exec_cmd("/etc/hypr/scripts/lan-mouse-toggle.sh toggle"))

hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
hl.bind("SUPER + E", hl.dsp.group.toggle())
hl.bind("SUPER + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + space", hl.dsp.exec_cmd("nwg-drawer -c 7 -is 64 -s /etc/hypr/nwg-drawer.css"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("rofi -show drun -theme /etc/hypr/rofi-tokyonight.rasi"))
hl.bind("CTRL + SUPER + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("/etc/hypr/scripts/power-menu.sh"))
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
    -- follow = false is the old movetoworkspacesilent.
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

local lettered = { I = 11, T = 12, O = 13, semicolon = 14 }
for key, ws in pairs(lettered) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = ws }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws, follow = false }))
end

hl.bind("SUPER + grave", hl.dsp.workspace.toggle_special())
hl.bind("SUPER + SHIFT + space", hl.dsp.window.move({ workspace = "special" }))

-- define_submap's optional second arg is NOT an escape key -- it is the submap
-- to jump to after any bind fires. Omitted, so resize mode stays sticky.
hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 2,  y = 0,  relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -2, y = 0,  relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,  y = -2, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,  y = 2,  relative = true }), { repeating = true })
    hl.bind("L",     hl.dsp.window.resize({ x = 2,  y = 0,  relative = true }), { repeating = true })
    hl.bind("H",     hl.dsp.window.resize({ x = -2, y = 0,  relative = true }), { repeating = true })
    hl.bind("J",     hl.dsp.window.resize({ x = 0,  y = -2, relative = true }), { repeating = true })
    hl.bind("K",     hl.dsp.window.resize({ x = 0,  y = 2,  relative = true }), { repeating = true })

    hl.bind("SHIFT + right", hl.dsp.window.resize({ x = 20,  y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + left",  hl.dsp.window.resize({ x = -20, y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + up",    hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true })
    hl.bind("SHIFT + down",  hl.dsp.window.resize({ x = 0,   y = 20,  relative = true }), { repeating = true })
    hl.bind("SHIFT + L",     hl.dsp.window.resize({ x = 20,  y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + H",     hl.dsp.window.resize({ x = -20, y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + J",     hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true })
    hl.bind("SHIFT + K",     hl.dsp.window.resize({ x = 0,   y = 20,  relative = true }), { repeating = true })

    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("return", hl.dsp.submap("reset"))
    hl.bind("SUPER + R", hl.dsp.submap("reset"))
end)

hl.bind("SUPER + R", hl.dsp.submap("resize"))

hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "up" }))

hl.bind("SUPER + ALT + H", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind("SUPER + ALT + L", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind("SUPER + ALT + K", hl.dsp.workspace.move({ monitor = "u" }))
hl.bind("SUPER + ALT + J", hl.dsp.workspace.move({ monitor = "d" }))

hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),  { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),{ locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })

hl.bind("Print",         hl.dsp.exec_cmd("/etc/hypr/scripts/screenshot.sh area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("/etc/hypr/scripts/screenshot.sh delayed 3"))
-- roach's keyboard has no Print key; these work everywhere.
hl.bind("SUPER + SHIFT + S",        hl.dsp.exec_cmd("/etc/hypr/scripts/screenshot.sh area"))
hl.bind("CTRL + SUPER + SHIFT + S", hl.dsp.exec_cmd("/etc/hypr/scripts/screenshot.sh delayed 3"))

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
