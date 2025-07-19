local astal = require("astal")
local astal_gtk3 = require("astal.gtk3")
local Widget = astal_gtk3.Widget
local astalify = astal_gtk3.astalify
local Gtk = astal_gtk3.Gtk
local Calendar = astalify(Gtk.Calendar)
local GLib = astal.require("GLib")
local WindowAnchor = astal.require("Astal", "3.0").WindowAnchor

return function(gdkmonitor, vertical_anchor, layer_namespace)
    local calendar_window = Widget.Window({
        setup = function(self)
            self:hide()
        end,
        class_name = "Calendar",
        gdkmonitor = gdkmonitor,
        namespace = layer_namespace,
        anchor = vertical_anchor + WindowAnchor.LEFT,
        margin_bottom = -10,
        margin_left = 20,
        Widget.EventBox({
            on_hover_lost = function(self)
                local parent = self:get_parent()
                if parent:is_visible() then
                    parent:hide()
                end
            end,
            Widget.Box({
                class_name = "Calendar",
                Calendar({
                    class_name = "CalendarPanel",
                }),
            }),
        }),
    })

    local calendar_button = Widget.Button()
    calendar_button.class_name = "Date"
    calendar_button.valign = "CENTER"
    calendar_button.halign = "CENTER"

    local weekday_label = Widget.Label()
    weekday_label.class_name = "Weekday"

    local date_label = Widget.Label()

    local label_container = Widget.Box({
        weekday_label,
        date_label,
    })

    calendar_button.child = label_container

    local interval = astal.interval(1000, function()
        weekday_label.label = GLib.DateTime.new_now_local():format("%A"):lower()
        date_label.label = GLib.DateTime.new_now_local():format("%d.%m.%Y")
    end)

    calendar_button.on_clicked = function()
        if calendar_window:is_visible() then
            calendar_window:hide()
        else
            calendar_window:show()
        end
    end
    calendar_button.on_destroy = function()
        interval.cancel()
    end
    return calendar_button
end
