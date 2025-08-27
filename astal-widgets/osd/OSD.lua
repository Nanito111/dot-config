local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local Anchor = astal.require("Astal").WindowAnchor
local Variable = require("astal").Variable
local bind = astal.bind
local timeout = astal.timeout

local Wp = astal.require("AstalWp")
local speaker = Wp.get_default().audio.default_speaker
local microphone = Wp.get_default().audio.default_microphone

local SHOW_TIME = 1 * 1000
local osd_icon = Variable.new()
local osd_level = Variable.new()
local widget_started = Variable.new(false)

local function show(window, window_timeout, level, icon)
    -- dont show widget at start
    if widget_started:get() == false then
        -- delayed flag setting
        timeout(500, function()
            widget_started:set(true)
        end)
        return
    end

    -- cancel hidding if timeout exist
    if window_timeout:get() ~= nil then
        window_timeout:get():cancel()
    end
    -- set new timeout
    window_timeout:set(timeout(SHOW_TIME, function()
        window:hide()
    end))

    osd_icon:set(icon)
    osd_level:set(level)
    window:show()
end

return function(gdkmonitor)
    local window_timeout = Variable.new()

    return Widget.Window({
        setup = function(self)
            local window = self
            -- speaker
            self:hook(speaker, "notify::volume", function(_)
                show(window, window_timeout, speaker.volume, speaker.volume_icon)
            end)
            self:hook(speaker, "notify::volume-icon", function(_)
                show(window, window_timeout, speaker.volume, speaker.volume_icon)
            end)

            -- microphone
            self:hook(microphone, "notify::volume", function(_)
                show(window, window_timeout, microphone.volume, microphone.volume_icon)
            end)
            self:hook(microphone, "notify::volume-icon", function(_)
                show(window, window_timeout, microphone.volume, microphone.volume_icon)
            end)
        end,
        class_name = "OnScreenDisplay",
        gdkmonitor = gdkmonitor,
        namespace = "astal-osd",
        anchor = Anchor.BOTTOM,
        margin_bottom = 300,
        width = 180,
        height = 38,
        layer = "OVERLAY",
        visible = false,
        Widget.Box({
            class_name = "base",
            Widget.Icon({
                icon = bind(osd_icon),
            }),
            Widget.LevelBar({
                valign = "CENTER",
                hexpand = true,
                value = bind(osd_level),
            }),
        }),
    })
end
