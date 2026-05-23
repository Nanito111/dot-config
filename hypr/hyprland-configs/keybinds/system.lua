-- hyprland-configs/keybinds/system.lua
-- Migrated from keybinds/system.conf

-- System binds
hl.bind(mainMod .. " + P",             hl.dsp.exec_cmd("caelestia shell lock lock"))
hl.bind(mainMod .. " + SHIFT + P",     hl.dsp.exec_cmd("pc-suspend"))
hl.bind(mainMod .. " + SHIFT + escape",hl.dsp.exec_cmd("pc-logout"))

-- Volume (sink)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),{ locked = true, repeating = true })

-- Custom volume keys (sink)
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SOURCE +"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SOURCE -"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SOURCE mute"), { repeating = true })

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SINK +"), { repeating = true })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SINK -"), { repeating = true })
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SINK mute"), { repeating = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Media
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),        { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),    { locked = true })

-- Zoom
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd(change_zoom .. " 1.2"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.exec_cmd(change_zoom .. " 0.8"))
hl.bind(mainMod .. " + mouse:274",  hl.dsp.exec_cmd("hyprctl -q keyword cursor:zoom_factor 1"))
