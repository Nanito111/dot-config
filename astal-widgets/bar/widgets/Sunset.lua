local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local bind = astal.bind
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor

local function Sunset()
    return Widget.Box({
        class_name = "SunsetContent",
        Widget.Slider({
            hexpand = true,
            min = 2500,
            max = 6000,
            step = 500,
            page = 100,
            on_dragged = function(self)
                -- speaker.volume = self.value
            end,
            -- value = bind(speaker, "volume"),
        }),
    })
end

return function(gdkmonitor)
    local sunset_window = Widget.Window({
        setup = function(self)
            self:hide()
        end,
        class_name = "Sunset",
        gdkmonitor = gdkmonitor,
        layer = "TOP",
        anchor = WindowAnchor.BOTTOM + WindowAnchor.RIGHT,
        margin_bottom = -10,
        margin_right = 20,
        Widget.EventBox({
            on_hover_lost = function(self)
                local parent = self:get_parent()
                if parent:is_visible() then
                    parent:hide()
                end
            end,
            Sunset(),
        }),
    })

    return Widget.Button({
        class_name = "ShowSunset",
        on_clicked = function()
            if sunset_window:is_visible() then
                sunset_window:hide()
            else
                sunset_window:show()
            end
        end,
        Widget.Icon({
            icon = "night-light-symbolic",
        }),
    })
end
