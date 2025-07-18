local astal = require("astal")
local Widget = require("astal.gtk3").Widget
local GLib = astal.require("GLib")

return function()
    local clock = Widget.Label()
    clock.class_name = "Time"

    local interval = astal.interval(1000, function()
        clock.label = GLib.DateTime.new_now_local():format("%H:%M:%S")
    end)

    clock.on_destroy = function()
        interval:cancel()
    end

    return clock
end
