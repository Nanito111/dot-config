-- hyprland-configs/keybinds/system.lua
-- Migrated from keybinds/system.conf

-- System binds
hl.bind(MainMod .. " + P",             hl.dsp.exec_cmd("caelestia shell lock lock"))
hl.bind(MainMod .. " + SHIFT + P",     hl.dsp.exec_cmd("pc-suspend"))
hl.bind(MainMod .. " + SHIFT + escape",hl.dsp.exec_cmd("pc-logout"))

-- Volume (sink)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),{ locked = true, repeating = true })

-- Custom volume keys (sink)
hl.bind(MainMod .. " + SHIFT + N", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SOURCE +"), { repeating = true })
hl.bind(MainMod .. " + SHIFT + B", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SOURCE -"), { repeating = true })
hl.bind(MainMod .. " + SHIFT + M", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SOURCE mute"), { repeating = true })

hl.bind(MainMod .. " + N", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SINK +"), { repeating = true })
hl.bind(MainMod .. " + B", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SINK -"), { repeating = true })
hl.bind(MainMod .. " + M", hl.dsp.exec_cmd(change_volume .. " DEFAULT_AUDIO_SINK mute"), { repeating = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Media
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),        { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),    { locked = true })

-- Zoom
local MAX_ZOOM = 5
local MIN_ZOOM = 1

---@param offset number
---@return nil
local function zoom(offset)
    local current = hl.get_config("cursor.zoom_factor")
    if offset ~= nil then
        current = current + offset
    elseif current ~= MIN_ZOOM then
        current = MIN_ZOOM
    else
        current = 0
    end
    current = math.max(MIN_ZOOM, math.min(MAX_ZOOM, current))
    hl.config({ cursor = { zoom_factor = current } })
end

hl.bind(MainMod .. " + mouse:274", zoom)
hl.bind(MainMod .. " + mouse_down", function()
    zoom(-0.2)
end)
hl.bind(MainMod .. " + mouse_up", function()
    zoom(0.2)
end)
