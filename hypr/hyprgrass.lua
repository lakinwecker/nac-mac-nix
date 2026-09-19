-- Touchscreen gestures. Appended to hyprland.lua by hypr/default.nix.

hl.plugin.load("/etc/hypr/plugins/hyprgrass.so")

hl.config({
    plugin = {
        touch_gestures = {
            sensitivity                  = 4.0,
            workspace_swipe              = true,
            workspace_swipe_fingers      = 3,
            workspace_swipe_edge         = "r",
            workspace_swipe_cancel_ratio = 0.15,
            emulate_touchpad_swipe       = true,
            long_press_delay             = 400,
            edge_margin                  = 100,
        },
    },
})

-- hl.plugin.hyprgrass is nil until the plugin loads after the first config
-- pass; without this guard that pass dies indexing a nil value.
local hg = hl.plugin.hyprgrass
if hg then

hg.bind({ pattern = "swipe:2:l", action = hl.dsp.window.move({ direction = "left" }) })
hg.bind({ pattern = "swipe:2:r", action = hl.dsp.window.move({ direction = "right" }) })
hg.bind({ pattern = "swipe:2:u", action = hl.dsp.window.move({ direction = "up" }) })
hg.bind({ pattern = "swipe:2:d", action = hl.dsp.window.move({ direction = "down" }) })

hg.bind({ pattern = "edge:u:d", action = hl.dsp.exec_cmd("wtype -M logo -m logo") })
hg.bind({ pattern = "edge:d:u", action = hl.dsp.exec_cmd("wvkbd-mobintl -H 400 -L 300") })
hg.bind({ pattern = "edge:d:d", action = hl.dsp.exec_cmd("pkill wvkbd") })
hg.bind({ pattern = "edge:3:u:d", action = hl.dsp.window.close() })

hg.bind({ pattern = "edge:r:l", action = hl.dsp.focus({ workspace = "+1" }) })
hg.bind({ pattern = "edge:l:r", action = hl.dsp.focus({ workspace = "-1" }) })

hg.bind({ pattern = "tap:3", action = hl.dsp.exec_cmd("toggle-keeb") })

hg.bind({ pattern = "edge:l:d", action = hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 4%-") })
hg.bind({ pattern = "edge:l:u", action = hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 4%+") })

-- mouse = true: hold the gesture to drag/resize.
hg.bind({ pattern = "longpress:2", action = hl.dsp.window.drag(),   mouse = true })
hg.bind({ pattern = "longpress:3", action = hl.dsp.window.resize(), mouse = true })

hg.bind({ pattern = "pinch:4:o", action = hl.dsp.window.fullscreen({ mode = "maximized" }) })
hg.bind({ pattern = "pinch:4:i", action = hl.dsp.window.fullscreen({ mode = "fullscreen" }) })

end
